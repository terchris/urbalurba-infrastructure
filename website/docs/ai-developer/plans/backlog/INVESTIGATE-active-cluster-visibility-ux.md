# Investigate: make the active cluster visible everywhere in the UIS shell + commands

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog (Tier 2 — UX safety, do after current AKS verification work closes)

**Last Updated**: 2026-05-10

**Source**: Tester's UX proposal in `testing/uis1/talk/UX-active-cluster-visibility.md` (2026-05-09). Originally triggered by the AKS Tier A verification rounds, where stale kubectl contexts produced silent failures — operators couldn't tell from prompt or command output that they were acting against a dead/wrong cluster.

---

## Problem Summary

Today there is **no signal** in the UIS shell or in `./uis` command output that tells the user which cluster the next destructive command will hit:

- The container prompt is `ansible@lima-rancher-desktop:/mnt/urbalurbadisk$` — that's the **lima VM hostname**, not the Kubernetes cluster. Identical whether kubeconfig points at Rancher Desktop, AKS, or a deleted context.
- `./uis deploy …`, `./uis expose …`, `./uis configure …` print colour-banner output (`[INFO]`, `[SUCCESS]`) that doesn't include the target cluster.
- `cluster-config.sh` (`TARGET_HOST` / `CLUSTER_TYPE`) and `kubectl current-context` can drift apart silently — and both being wrong-but-self-consistent is also possible.

**Blast radius**: whatever cluster `kubectl` happens to be pointed at. A wrong context can produce a destructive operation against the wrong cluster with no signal in the workflow to catch it.

### Concrete recent incidents this would have prevented

- **Tier A retry №3 silent false positive** (PR #149 testing) — tester's `./uis deploy nginx` ran a phantom replay against rancher-desktop's existing release while the brand-new AKS cluster sat empty. Both the playbook output and the helm chain reported "success". A cluster-banner at the top of `./uis deploy` would have shown `kube_context = rancher-desktop` (not `azure-aks`) and the tester would have caught it before declaring the round green.
- **Stale port-forward after AKS destroy** (talk41 round) — `kubeconf-all`'s `current-context` still pointed at the destroyed cluster after `03-destroy.sh`. `./uis expose postgresql` happily reported `[SUCCESS]` while `kubectl port-forward` zombied behind the scenes. A reachability probe in Layer 1 (below) would have aborted before the port-forward attempt.
- **Earlier multi-cluster confusion incidents** — talk37 (postgres purge) and talk23-ish (backstage 401 verify) both involved "where is this command actually going" ambiguity.

---

## Two questions to settle before designing

### Q1 — What is "the active cluster"?

Two candidates:

- `cluster-config.sh`'s `TARGET_HOST` — what UIS *thinks* it's targeting (Ansible inventory hint, sourced by service-deployment scripts).
- `kubectl current-context` — what `kubectl` / `helm` actually talks to.

The truth is **both must agree**, and divergence between them is its own class of bug worth surfacing (the Tier A rounds had this exact divergence).

**Proposal to validate**: surface kubectl current-context as the *primary* signal (it's what actually fires the API calls), and emit a warning when `cluster-config.sh` disagrees. This frames cluster-config as a hint, kubectl context as truth.

### Q2 — Where should the signal live?

- **Container prompt (PS1)** — visible all the time, no per-command cost. Catches "what am I about to do" before commands run.
- **Per-`./uis` command output** — visible per command, including from outside the shell. Makes logs/screenshots self-describing.
- **Both** — they serve different audiences. Both are cheap.

---

## Three-layer design sketch

### Layer 1 — `./uis` output banner (do first, lowest risk, broadest reach)

Every `./uis` subcommand that touches a cluster prints a one-line banner before its first action:

```
ℹ  Cluster: rancher-desktop  (kubectl: rancher-desktop, config: rancher-desktop)
```

Divergence:

```
⚠  Cluster mismatch — kubectl: azure-aks, cluster-config.sh: rancher-desktop
   These should agree. Continuing with kubectl context.
```

API server unreachable (talk41 case):

```
✗  Cluster: azure-aks (kubectl), but the API server is unreachable.
   Likely the cluster was destroyed. Run './uis cluster reset' or fix kubeconfig.
   Aborting.
```

**Implementation shape**: a sourced helper (`provision-host/uis/lib/cluster-banner.sh`, ~30 lines) called at the top of each cluster-touching command. One-shot reachability probe (`kubectl --request-timeout=3s get --raw /version`); fails fast.

**Touches**: `./uis deploy`, `./uis undeploy`, `./uis configure`, `./uis expose`, `./uis status`, `./uis list`, `./uis stack install`, `./uis test-all`. Skip purely informational commands (`./uis help`, `./uis version`, `./uis container`).

### Layer 2 — coloured PS1 inside `./uis shell`

Modify the container's bashrc so PS1 includes a cluster tag:

```
[rancher-desktop] ansible@uis:/mnt/urbalurbadisk$
```

Colour by sensitivity:

| Cluster type | Colour | Why |
|---|---|---|
| `rancher-desktop` (or anything tagged "local" in cluster types) | green | safe sandbox |
| `azure-aks`, `aws-eks`, `gcp-gke` (sandbox tier) | yellow | cloud, real cost, but disposable |
| Anything explicitly tagged `production` in cluster-config.sh | red, with the word `PROD` | maximum visibility |

Driven off two sources, with kubectl-context winning. Re-evaluated on each prompt; switches mid-session update immediately.

While we're touching the prompt: replace the misleading `lima-rancher-desktop` hostname (`\h` shows the lima VM, not the cluster). Either drop `\h` or substitute a fixed `uis` literal.

### Layer 3 — `./uis status` should make this its first line

Today's `./uis status` shows deployed services. The header should be:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
UIS Status
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Cluster:    rancher-desktop  (reachable, k8s v1.32.0)
Context:    rancher-desktop
Config:     rancher-desktop  ✓ matches kubectl
Namespace:  default

Deployed services:
  …
```

Makes "where am I" the first thing the operator sees on the standard "what's going on" command.

---

## Edge cases to think through during design

1. **No cluster reachable at all** (e.g. Rancher Desktop stopped). Layer 1's probe should detect this and tell the user "no cluster reachable; start Rancher Desktop" rather than emit cryptic kubectl timeouts.
2. **Multiple kubeconfig files** — UIS uses `kubeconf-all` (merged) but operators sometimes override `KUBECONFIG`. The probe should respect whatever `KUBECONFIG` resolves to, not hard-code a path.
3. **Performance** — adding a kubectl probe to every UIS command costs ~50–200 ms. Acceptable for safety; mitigate with a 10s probe cache in `/tmp` if it becomes noisy.
4. **CI / non-interactive contexts** — colour codes should respect `NO_COLOR=1` and detect non-TTY (`[[ -t 1 ]]`). Banner stays, just without ANSI.
5. **`./uis` invoked from outside `./uis shell`** — the wrapper docker-execs into the container; PS1 doesn't help there. Layer 1 covers this.
6. **Nested invocations** — `./uis test-all` or `./uis stack install` runs many sub-commands. Banner per sub-command is noisy. Print once at the parent invocation; sub-commands inherit silently via env var (`UIS_BANNER_PRINTED=1`).

---

## Suggested rollout

1. **Layer 1 first.** Covers everyone — in-shell users, host-side `./uis` invokers, future automation. Lowest implementation cost. Tracer-bullet through `./uis deploy` first; if that reads cleanly, fan out to the rest.
2. **Layer 3 next.** `./uis status` is a one-script change.
3. **Layer 2 last.** Touching the container's bashrc coordinates with the container build.

Each layer ships independently — Layer 1 alone delivers most of the value.

---

## Out of scope for this investigation (deliberately)

- **Multi-context awareness** in a single `./uis` invocation (e.g. "deploy this to both local and AKS"). UIS is single-cluster-per-invocation today; broadening that is its own design problem.
- **Production-vs-sandbox enforcement.** Once Layer 2's colour scheme is in, building actual confirmation prompts ("Type the cluster name to continue against PROD") is a natural follow-up but separate.
- **Cluster-config-as-source-of-truth refactor.** Today we have two sources (cluster-config.sh + kubectl context) that can disagree. Picking one as canonical and deriving the other is bigger than this proposal — this proposal just makes the disagreement visible.

---

## What this investigation needs to produce

A child PLAN that decides:

1. Whether kubectl context is the canonical signal (vs. cluster-config.sh) — see Q1.
2. Which of Layer 1 / 2 / 3 ships first, and in what PR order.
3. The exact API of `cluster-banner.sh` (function signature, env-var contract for nesting, colour-strip rules).
4. Where the reachability probe lives (per-command at top, or in a single shared `cluster-touch` guard).

Once those four are settled, Layer 1 should be a small PR (~30 lines of bash + a few dozen call sites adding `cluster_banner` at the top).

## Related

- [PLAN-aks-destroy-kubeconfig-cleanup.md](./PLAN-aks-destroy-kubeconfig-cleanup.md) — fixes one source of the "stale kubectl context" problem this UX surfaces. Both plans address the same operator-safety concern from different angles.
- Tester's original write-up: `testing/uis1/talk/UX-active-cluster-visibility.md` (2026-05-09).

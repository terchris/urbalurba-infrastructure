# Investigate: cluster visibility + switching across the UIS shell and commands

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog (Tier 2 — UX safety; scope expanded 2026-05-10 to include cluster switching)

**Last Updated**: 2026-05-10

**Source**: Tester's UX proposal in `testing/uis1/talk/UX-active-cluster-visibility.md` (2026-05-09). Originally triggered by the AKS Tier A verification rounds, where stale kubectl contexts produced silent failures — operators couldn't tell from prompt or command output that they were acting against a dead/wrong cluster.

**Scope expansion 2026-05-10**: this investigation originally covered only *visibility* (banner, PS1, status header). When the AKS novice-onboarding investigation ([INVESTIGATE-aks-novice-onboarding.md](./INVESTIGATE-aks-novice-onboarding.md)) proposed `./uis platform up azure-aks` as a wrapper that ships clusters in 5 commands, "I now have rancher-desktop and azure-aks both running, how do I switch?" became the load-bearing follow-up. Switching folds in here because it shares the same source-of-truth question (Q1) and the same reachability-probe building block as the visibility layers; splitting the two would risk the investigations picking different definitions of "the active cluster".

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

### The switching gap (added 2026-05-10)

Beyond visibility, there's no first-class way to *change* the active cluster from inside UIS:

- **No inventory.** "Which clusters do I have?" requires reading `kubectl config get-contexts` + `.uis.secrets/cloud-accounts/*.env` + `cluster-config.sh` history by hand and reconciling them mentally.
- **No switch verb.** Moving from rancher-desktop to azure-aks today means `kubectl config use-context azure-aks` (which doesn't flip cluster-config.sh's `TARGET_HOST`), plus a manual edit of cluster-config.sh to match. The two halves of "the active cluster" drift every time someone forgets the second step.
- **No reachability gate on switch.** Switching to a destroyed cluster's stale context "succeeds" silently until the next `kubectl` call times out — same failure mode as the talk41 stale-port-forward incident, just triggered earlier.

The platform wrappers ([INVESTIGATE-aks-novice-onboarding.md](./INVESTIGATE-aks-novice-onboarding.md)) make this gap concrete: once `./uis platform up azure-aks` lands, every novice has 2+ clusters within their first session and immediately needs `list` + `use`.

---

## Design questions to settle

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

### Q3 — What's in the cluster inventory?

`./uis platform list` (Layer 4 below) needs to enumerate available clusters from somewhere. Three candidate sources, each with different drift modes:

- **Kubeconfig contexts** (`kubectl config get-contexts`). Authoritative for "what `kubectl` can connect to", but accumulates stale entries from destroyed clusters that nothing prunes.
- **`.uis.secrets/cloud-accounts/*.env` files**. Tells you "what UIS *can* provision/manage" and survives `down`. Says nothing about whether the cluster is currently up.
- **`cluster-config.sh` history**. Only knows about the *last* cluster UIS touched, not the full set.

**Proposal to validate**: union all three. Annotate each entry with reachability (`✓ reachable / ✗ unreachable / · not currently provisioned`) and a "last active" timestamp. Stale kubeconfig entries (in kubeconfig but unreachable, with no live cloud-account) are surfaced as candidates for cleanup.

### Q4 — How does `use` write the active cluster?

Switching means flipping both `kubectl current-context` and `cluster-config.sh`'s `TARGET_HOST` so they agree. Three options:

- **(a) Lockstep flip.** Concrete and explicit; adds a write path to `cluster-config.sh` that today only `02-post-apply.sh` ever touches.
- **(b) Flip kubectl context only; treat `cluster-config.sh` as derived.** Regenerate `TARGET_HOST` from the new context's name on every read. Simpler invariant but requires that context names map cleanly to UIS cluster types — true today (`rancher-desktop`, `azure-aks`) but fragile if someone renames a context.
- **(c) Flip kubectl context, then warn if `cluster-config.sh` disagrees** — leaving the user to decide. Punts the problem and breaks Q1's "both must agree" invariant.

**Proposal to validate**: (a) lockstep flip. Bounds Q1: `kubectl current-context` is *truth for reads*, `use` writes both atomically, `cluster-config.sh` becomes a cached projection that's always written by `use` and never read independently for "active cluster" decisions.

### Q5 — What's the switch verb?

`./uis platform use <name>` (kubectl-style, fast, no reachability check) vs `./uis platform switch <name>` (with reachability probe + lockstep flip)? Or just one verb with both behaviours?

**Proposal to validate**: one verb, `use`, with reachability-probe-and-refuse semantics by default. If the user explicitly wants to switch to an unreachable cluster (e.g. to clean up a stale kubeconfig entry), they can pass `--no-probe`. Matches `kubectl config use-context` in feel; matches Layer 1's reachability-aborts-on-unreachable in safety.

---

## Layered design sketch

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

### Layer 4 — `./uis platform list / use` (the switching half)

Two new commands, parallel to `./uis platform up/down/init` from the novice-onboarding investigation.

**`./uis platform list`** — enumerate available clusters with status:

```
Active: rancher-desktop

CLUSTER          KUBECTL          STATUS         LAST ACTIVE
azure-aks        azure-aks        ✓ reachable    2 hours ago
rancher-desktop  rancher-desktop  ✓ reachable    now (active)
azure-aks-old    azure-aks-old    ✗ unreachable  destroyed?  (stale; 'use --no-probe' to clean)
```

Sources unioned per Q3. Reachability per row uses Layer 1's `kubectl --request-timeout=3s get --raw /version` probe (in parallel for fast `list`).

**`./uis platform use <name>`** — switch the active cluster:

```
$ ./uis platform use azure-aks
ℹ  Probing azure-aks ... ✓ reachable (k8s v1.32.0)
✓  Active cluster: rancher-desktop → azure-aks
   kubectl current-context: azure-aks
   cluster-config.sh:       azure-aks (synced)
```

Per Q4 — flips kubectl context and `cluster-config.sh` in lockstep. Per Q5 — refuses to switch to an unreachable cluster unless `--no-probe` is passed. With no argument, presents an interactive picker (numbered list; `fzf` if available, plain `read` prompt otherwise).

**Implementation shape**: `cmd_platform_list` and `cmd_platform_use` in `provision-host/uis/manage/uis-cli.sh`, delegating to a shared helper at `provision-host/uis/lib/platform-switching.sh` (~60 lines). Re-uses the reachability probe from `cluster-banner.sh` (Layer 1). No external dependencies beyond `kubectl` and `bash`.

**Edge cases this layer adds**:
- Switching to a context that exists in kubeconfig but no longer exists as a UIS cluster (e.g. tester's personal cluster) — allowed, but the post-switch banner notes "kubectl-only context, no `cluster-config.sh` entry".
- Concurrent `use` from two terminals — last write wins; `cluster-config.sh` has no locking. Document this; don't engineer it.
- `use` to the *current* active cluster — no-op + cheap reachability re-probe; useful as a "is my cluster still up?" probe.

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
2. **Layer 4 next.** `./uis platform list / use` ships once Layer 1's reachability probe is reusable as a sourced helper. Unblocks anyone with 2+ clusters from manually editing kubeconfig + `cluster-config.sh` to rotate the active cluster.
3. **Layer 3 third.** `./uis status` becomes the obvious "where am I and what else is reachable?" command once `list` exists — single-script change to add the cluster header (and a one-line "other clusters: …" pointer to `list`).
4. **Layer 2 last.** Touching the container's bashrc coordinates with the container build.

Each layer ships independently — Layer 1 alone delivers most of the visibility value, Layer 4 alone delivers the switching value.

---

## Out of scope for this investigation (deliberately)

- **Cross-cluster broadcasts** in a single `./uis` invocation (e.g. "deploy this to both local AND AKS"). UIS stays single-cluster-per-invocation; switching just makes it cheap to rotate which cluster that is.
- **Production-vs-sandbox enforcement.** Once Layer 2's colour scheme is in, building actual confirmation prompts ("Type the cluster name to continue against PROD") is a natural follow-up but separate.
- **Removing `cluster-config.sh` entirely.** Q4's lockstep-flip proposal bounds the source-of-truth question (kubectl context = truth for reads, `use` writes both atomically, `cluster-config.sh` is a derived projection). A larger refactor that removes `cluster-config.sh` outright (everything reads kubectl context, nothing reads `cluster-config.sh`) is a separate question. Mostly an Ansible-inventory-shape change rather than a UX one.
- **Provisioning new clusters from `list`.** `list` shows what exists; provisioning is `./uis platform up <name>` (separate command, scoped in [INVESTIGATE-aks-novice-onboarding.md](./INVESTIGATE-aks-novice-onboarding.md)). No "click to provision" affordance from inside `list`.

---

## What this investigation needs to produce

A child PLAN (or two — one for visibility layers, one for switching) that decides:

1. Whether kubectl context is the canonical signal — see Q1, bounded by Q4's lockstep-flip proposal.
2. Inventory source for `list` — see Q3.
3. Switch atomicity — see Q4. Lockstep vs derived.
4. Switch verb + reachability semantics — see Q5.
5. Which layer (1 / 2 / 3 / 4) ships first, and in what PR order.
6. Where the reachability probe lives (per-command at top of cluster-touching commands, vs. a single shared `cluster-touch` guard) — and how `platform-switching.sh` re-uses it.
7. The exact API of `cluster-banner.sh` and `platform-switching.sh` (function signatures, env-var contract for nesting, colour-strip rules).

Once those settle, Layer 1 is a small PR (~30 lines of bash for the banner helper + a few dozen call sites). Layer 4 is a similar-sized PR (~60 lines of `platform-switching.sh` + two thin `cmd_platform_*` dispatchers in `uis-cli.sh`). Layers 2 and 3 are smaller still.

## Related

- [INVESTIGATE-aks-novice-onboarding.md](./INVESTIGATE-aks-novice-onboarding.md) — proposes the `./uis platform <verb> <target>` shape this investigation extends with `list` + `use` verbs. The two investigations share Q1 (canonical signal) and the reachability-probe building block. Land Layer 4 alongside the platform-wrappers PRs so novices are never stuck after `./uis platform up azure-aks` with no way to see or rotate what they've created.
- [PLAN-aks-destroy-kubeconfig-cleanup.md](./PLAN-aks-destroy-kubeconfig-cleanup.md) — fixes one source of the "stale kubectl context" problem this UX surfaces. Both plans address the same operator-safety concern from different angles.
- Tester's original write-up: `testing/uis1/talk/UX-active-cluster-visibility.md` (2026-05-09).

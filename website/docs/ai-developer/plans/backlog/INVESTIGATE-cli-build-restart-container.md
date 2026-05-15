# INVESTIGATE: `./uis build` should restart the container after a successful build

**Status:** Investigation needed
**Created:** 2026-05-13
**Surfaced by:** talk52 F1 (Tailscale architecture cleanup verification)

---

## Problem Statement

`./uis build` produces a new local image but does not stop or recreate the running container, so subsequent commands silently use the previous image. This caused a confusing diagnostic loop during talk52 R2: the tester observed the running container's bundled templates were stale, attributed it to a stale image, and only after a `docker run --rm` comparison did the contributor identify that the *container* was stale, not the *image*.

The same pattern works correctly for `./uis pull` — it calls `stop_container` + `start_container` after pulling. The `build` branch is missing the equivalent.

## Current Behavior

`uis:272-276`:

```bash
build)
    log_info "Building UIS container image..."
    docker build -f "$SCRIPT_DIR/Dockerfile.uis-provision-host" -t uis-provision-host:local "$SCRIPT_DIR"
    log_info "Build complete"
    ;;
```

That's the entire `build` branch. After the build completes, `start_container()` (uis:103) sees the existing container running with the old image and short-circuits to "already running" — `$IMAGE` is never re-applied.

`uis:174-189` (pull) for contrast:

```bash
pull_container() {
    log_info "Pulling latest UIS container image..."
    if docker pull "$IMAGE"; then
        log_info "Image updated successfully"
        if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
            log_info "Restarting container with new image..."
            stop_container
            start_container
            log_info "Container restarted with new image"
        ...
```

## Proposed Fix

Mirror the `pull` behavior in `build`:

```bash
build)
    log_info "Building UIS container image..."
    docker build -f "$SCRIPT_DIR/Dockerfile.uis-provision-host" -t uis-provision-host:local "$SCRIPT_DIR"
    log_info "Build complete"
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        log_info "Restarting container with new local image..."
        UIS_IMAGE=uis-provision-host:local stop_container
        UIS_IMAGE=uis-provision-host:local start_container
        log_info "Container restarted on uis-provision-host:local"
    fi
    ;;
```

**Caveat to investigate**: `./uis build` may be called by users who DON'T want their running container disturbed (e.g. CI-style "just verify the build doesn't error"). Options:
- Always restart (simplest; matches `pull`)
- Only restart if `UIS_IMAGE=uis-provision-host:local` (or unset, meaning default-to-local)
- Add `--restart` / `--no-restart` flag

## Out of Scope (already handled)

- The `./uis stop` workaround for the current state is documented in talk52's F1 reply — no doc gap to fix.
- This is a `main`-branch issue, predates the Tailscale work — landing the fix on `main` is independent of the Tailscale PR.

## Open Questions

- Is anyone deliberately depending on the current "build doesn't restart" behavior? Likely no, but worth a sanity ping before changing.
- Should `./uis build` also default to `UIS_IMAGE=uis-provision-host:local` for the immediate subsequent commands (set it in the user's shell), or is the `UIS_IMAGE=...` prefix on every command actually the right ergonomics?

# Containerdemo Modernization Plan

## Top-Level Overview

**Goal:** Bring the "Container in Go" demo up to date (toolchain, Dockerfile, cgroup handling, scripts, docs, CI) **without changing what the demo teaches**.

**Guiding principle:** The technical story stays as it is. The 8-step progression (`Versions/main1.go` to `main8.go`), the `snippets.txt` live-coding flow, the `/proc/self/exe` re-exec trick, `chroot`, the `proc` mount, `Cloneflags`/`Unshareflags` and the cgroup v2 `pids.max` fork-bomb finale are all kept. Additions are small and only included where they clearly pay off.

**Explicit non-goals**
- **Ubuntu stays.** The host image stays on `ubuntu:24.04` and the inner "container" root filesystem stays an exported Ubuntu (`ubuntu.tar`). No UBI / Red Hat images. This is a personal, non-IBM project presented to an external audience, and Ubuntu is the distribution most of that audience knows.
- No rewrite to `pivot_root`, no user namespaces, no network namespace, no OCI runtime features. These are mentioned in the docs as "further reading" only.
- No switch from the `syscall` package to `golang.org/x/sys/unix` (`syscall.SysProcAttr` is still required by `os/exec`, and `syscall` keeps the snippets short on stage).
- No restructuring of `Versions/` (the `cp Versions/main1.go main.go` reset workflow stays).
- The final image keeps the Go toolchain, because the demo edits and runs `main.go` live inside the container.

### Findings from the current code (evidence)

| Area | Finding | File |
|---|---|---|
| Dockerfile | Go is installed through a third-party PPA (`ppa:longsleep/golang-backports`) plus `software-properties-common`; the tag `ubuntu:24.04` is not pinned by digest | [`Dockerfile`](Dockerfile:1) |
| Dockerfile | Several `RUN` layers, no `--no-install-recommends`, no apt cache cleanup, trailing whitespace after `\` on line 4 | [`Dockerfile`](Dockerfile:3) |
| Dockerfile | `touch HOST-ROOT /` and `touch CONTAINER-ROOT /opt/container-filesystem` are the marker files used to show host vs. container root (keep) | [`Dockerfile`](Dockerfile:8) |
| Script | No `set -euo pipefail`; container ID found via `docker ps \| grep \| cut`; `docker remove` instead of `docker rm`; hard-wired to `docker` while a comment mentions podman | [`createDemoContainer.sh`](createDemoContainer.sh:1) |
| Go | No `go.mod`; redundant legacy `// +build linux` line (obsolete since Go 1.17) | [`main.go`](main.go:1) |
| Go | `os.Args[1]` panics with an index error when no args are given; `panic("help")` is the usage message | [`main.go`](main.go:14) |
| Go | Errors from `cmd.Run`, `Sethostname`, `Chroot`, `Chdir`, `Mount`, `Unmount` are silently ignored, so a missing privilege shows up as confusing behaviour | [`Versions/main8.go`](Versions/main8.go:52) |
| Go | `cg()` writes `+pids` to the *root* `cgroup.subtree_control`, uses `cgroup.type=threaded` plus `cgroup.threads`, and never removes the cgroup. Whether this works depends on the cgroup namespace and the "no internal processes" rule of the runtime, so it must be verified on current Docker/Podman | [`Versions/main8.go`](Versions/main8.go:62) |
| Go | Typo "current pis" in comment | [`Versions/main8.go`](Versions/main8.go:89) |
| Run docs | `--cap-add SYS_ADMIN --privileged` is redundant (`--privileged` already grants all capabilities) | [`README.md`](README.md:16) |
| Docs | Bear notes still use old names `dockerdemo` / `/sys/fs/cgroup/dockerdemo` and "Define max pods" (should be pids); the code uses `containerdemo` | [`Documentation/BearNotes.md`](Documentation/BearNotes.md:49) |
| Docs | `snippets.txt` mixes tabs/spaces and its cgroup snippet duplicates `main8.go` | [`snippets.txt`](snippets.txt:59) |
| Repo | No CI, no lint config. All `Versions/*.go` are `package main` in one directory, so a plain `go build ./...` / `go vet ./...` there fails on duplicate `main` | `Versions/` |

### Privilege note (technical, not a policy item)

The demo inherently needs root and `CAP_SYS_ADMIN` inside the container (creating namespaces, `chroot`, mounting `proc`, writing cgroups). The plan keeps that, but narrows the run command from `--privileged` to the verified minimum and documents in the README that the demo should be run on a disposable local machine or VM.

---

## Sub-Tasks

Each sub-task is independent and reviewable on its own. Recommended order is as listed.

### 1. Go module and source hygiene (minimal)
**Intent:** Make the code buildable and checkable with current Go tooling without altering the teaching flow.

**Expected Outcomes**
- `go.mod` exists with a current stable Go version (verified at implementation time).
- `main.go` and all `Versions/main*.go` pass `gofmt` and `go vet` when checked individually.
- Behaviour of each step is unchanged.

**Todo List**
- [x] Add `go.mod` (module `github.com/mhenke1/containerdemo`, no external dependencies).
- [x] Remove the obsolete `// +build linux` line and keep `//go:build linux` in `main.go` and the `Versions` files.
- [x] Check `os.Args` length in `main()` and print a one-line usage message (`usage: go run main.go run <cmd> [args...]`) instead of an index panic. Keep it short so it stays easy to show on stage.
- [x] Fix the "pis" typo comment in the cgroup code (`main8.go`, `snippets.txt`).
- [x] Run `gofmt -l` and `go vet` on each file, one by one.

**Relevant Context:** [`main.go`](main.go), [`Versions/`](Versions), [`snippets.txt`](snippets.txt). `main.go` is the live working copy; `Versions/main1.go` is the reset state.

**Status:** [x] done

**Implementation notes (for Sub-Task 2 and later):**
- `go.mod` uses `go 1.27.1` (matches the installed `go version go1.27.1`). Sub-Task 4 should pin the same Go version in the Dockerfile (`golang:1.27.1`) or lower the directive to match.
- Usage check is in `main()` of `main.go` and `Versions/main1.go`..`main8.go`, placed before `switch os.Args[1]`: `if len(os.Args) < 3 { fmt.Println("usage: go run main.go run <cmd> [args...]"); os.Exit(1) }`. `< 3` also covers `run` without a command (previously an index panic in `run()`). `panic("help")` for unknown subcommands is unchanged. `fmt` and `os` were already imported in every file.
- The check is also hit by the re-exec'd `child` invocation, which always has `os.Args >= 3`, so behaviour is unchanged.
- The typo fix was "pis" -> "pid" in `Versions/main8.go` and `snippets.txt`. `snippets.txt` needed no other change: the usage check sits in `main()`, which no "N to N+1" snippet touches.
- `gofmt -l` is clean and `GOOS=linux go vet <file>` passes for each of the 9 files. Checked from macOS: `go run main.go` (no args) prints the usage line and exits 1, because files named on the command line bypass the `linux` build constraint.
- For Sub-Task 2: the `must(err)` helper will need `fmt` and `os` (already imported). Line numbers in `Versions/main*.go` shifted by +5 from the usage block; `main8.go` `cg()` now starts around line 67.
- Pre-existing, not touched: `snippets.txt` still has mixed tabs/spaces and a trailing-space line after `syscall.Unmount("proc", 0)` (Sub-Task 7).

---

### 2. Error handling in the later steps (small, teaching-friendly)
**Intent:** Stop silently ignoring failures from the privileged calls, which is the most common cause of "the demo does not work" on a new Docker/Podman version.

**Expected Outcomes**
- Failing `Sethostname`, `Chroot`, `Chdir`, `Mount`, and `cmd.Run` report a clear error and exit non-zero.
- Code stays short: a tiny `must(err)` helper rather than repeated `if err != nil` blocks.
- Step-to-step diffs in `snippets.txt` remain small.

**Todo List**
- [x] Introduce a small `must(err error)` helper in `Versions/main3.go` onward (first introduced where the first privileged call appears) and use it for the syscalls.
- [x] Handle `cmd.Run()` errors in `run()` and `child()` (print and `os.Exit(1)`).
- [x] Keep the `syscall.Unmount("proc", 0)` after the command and make sure it still runs.
- [x] Update the matching snippets in `snippets.txt` so the "N to N+1" diffs still match the files.

**Relevant Context:** [`Versions/main3.go`](Versions/main3.go) to [`Versions/main8.go`](Versions/main8.go), [`snippets.txt`](snippets.txt).

**Status:** [x] done

**Implementation notes (for Sub-Task 3 and later):**
- Helper: `func must(err error) { if err != nil { fmt.Fprintln(os.Stderr, "error:", err); os.Exit(1) } }`. It sits directly after `main()` in `Versions/main3.go`..`main8.go` and is identical in all of them. It uses the already imported `fmt` and `os`. It prints `error: <err>` and exits 1, so a child that exits non-zero (e.g. `exit 1`) shows `error: exit status 1` and no panic trace.
- `must(...)` wraps `Sethostname` (main3+), `Chroot` and `os.Chdir` (main5+), `Mount` (main6+), and `cmd.Run()` in `run()` and `child()` (main3+).
- main6..main8 `child()`: `err := cmd.Run()`, then `syscall.Unmount("proc", 0)`, then `must(err)`. This guarantees Unmount runs even if the command fails. The `Unmount` error is still ignored on purpose (it runs at teardown, and a second error would hide the command's error).
- Because `must` exits via `os.Exit`, an early failure before `cmd.Run` (e.g. `Mount`) skips the Unmount, which is correct: nothing was mounted.
- `cg()` in `main8.go` is unchanged and still uses `panic(err)` (converting would not simplify it). It now starts at line 74 (`func cg()`), ends at line 108; the call `cg()` is in `child()` at line 56. Sub-Task 3 must keep `snippets.txt` (7 to 8 snippet) identical to it.
- `snippets.txt`: the "2 to 3" snippet now includes `must()` and labels `# in run()` / `# in child()`; "4 to 5" and "5 to 6" use `must(...)`. The "5 to 6" snippet ends with `err := cmd.Run()`, `Unmount`, `must(err)`. Removed the trailing spaces after `Unmount` in that snippet; other whitespace is untouched (Sub-Task 7).
- `main.go` stays identical to `Versions/main1.go` (step-1 state). It is only run inside the container with `docker run`.
- Validation: `gofmt -l` clean and `GOOS=linux go vet <file>` passes for all 9 files; consecutive `diff` output matches the snippets. Not run on Linux (no container runtime used).

---

### 3. Verify and tidy the cgroup v2 step
**Intent:** Confirm the cgroup v2 limit still works on current Docker Desktop / Docker Engine / Podman, and fix only what is shown to be broken.

**Expected Outcomes**
- A documented, tested result for `cg()` on the supported runtimes (which pass, which need extra flags such as a private cgroup namespace).
- The `pids.max` fork-bomb finale works as shown in `snippets.txt`.
- The demo cgroup directory is removed on exit (small addition, avoids stale state between runs).

**Todo List**
- [x] Test `main8.go` in the rebuilt container on the target runtime(s); record whether the root `cgroup.subtree_control` write and the `threaded` type are really needed.
- [x] If a simpler form works (create `containerdemo`, set `pids.max`, write PID to `cgroup.procs`), propose it; otherwise keep the current approach unchanged and add a short comment explaining why.
- [x] Remove the cgroup directory after the child exits (`os.Remove`), ignoring "busy" errors.
- [x] Update `main8.go` and the cgroup snippet in `snippets.txt` identically.
- [x] Note the `watch` command path (`/sys/fs/cgroup/containerdemo/pids.current`) in the docs.

**Relevant Context:** [`Versions/main8.go`](Versions/main8.go:62), [`snippets.txt`](snippets.txt:56). Needs a Linux container runtime to verify, so this step requires running commands in Agent mode.

**Status:** [x] done

**Implementation notes (for Sub-Task 6 and later):**

#### Runtime Test Results Matrix

Tested on Docker 29.2.1 (Ubuntu 24.04 kernel, cgroup v2, cgroupfs driver on macOS Apple Silicon). Podman machine was NOT running and was not tested (per instructions).

| Runtime & Flags | Result | Details / Root Cause |
|---|---|---|
| `docker run --privileged` (README current flags minus redundant `--cap-add`) | **PASS** | `/sys/fs/cgroup` is mounted rw, private cgroupns active. `+pids` enables controller, `threaded` avoids internal-process restriction, `pids.max=20` enforced (bounded fork test failed at 18th background sleep), cgroup cleaned up on exit. |
| `docker run --privileged --cap-add SYS_ADMIN` (current README flags) | **PASS** | Works identically (`--cap-add SYS_ADMIN` is redundant when `--privileged` is present). |
| `docker run --cap-add SYS_ADMIN` (without privileged) | **FAIL** | `/sys/fs/cgroup` is mounted `ro` by Docker; `mkdir /sys/fs/cgroup/containerdemo` fails with Read-only file system. Remounting rw fails (write-protected). |
| `docker run --cap-add SYS_ADMIN --cgroupns=private` | **FAIL** | `/sys/fs/cgroup` is still mounted `ro` by Docker. |
| `docker run --cap-add SYS_ADMIN -v /sys/fs/cgroup:/sys/fs/cgroup:rw` | **FAIL** | `fork/exec /proc/self/exe: permission denied` due to Docker's default AppArmor profile blocking `CLONE_NEWPID` / namespace creation without `--privileged` or `--security-opt apparmor=unconfined`. |
| `docker run --cap-add SYS_ADMIN -v /sys/fs/cgroup:/sys/fs/cgroup:rw --security-opt apparmor=unconfined --security-opt seccomp=unconfined` | **FAIL** | Bypasses AppArmor, but mounting host cgroup root means `cgroup.threads` write fails (`EOPNOTSUPP`) because the host root is not a threaded cgroup. |

#### Technical Findings on Cgroup v2 Structure

1. **Root `cgroup.subtree_control` write (`+pids`):** REQUIRED. Without writing `+pids` to the parent's `cgroup.subtree_control`, the child cgroup (`containerdemo`) does not expose `pids.*` controller files (`pids.max` does not exist).
2. **`cgroup.type=threaded` and `cgroup.threads`:** REQUIRED in container environments. In Docker's private cgroup namespace, the container's root cgroup already contains processes (e.g. PID 1 / bash). Under cgroup v2's "no internal processes" rule for non-root domain cgroups, enabling subtree controllers causes child domain cgroups to become `domain invalid`, and writing to `cgroup.procs` fails with `Operation not supported` (`EOPNOTSUPP`). Setting `cgroup.type=threaded` and writing to `cgroup.threads` avoids this rule and allows `pids.max` enforcement.
3. **Cgroup Cleanup:** Added `os.Remove("/sys/fs/cgroup/containerdemo")` to `run()` after `err := cmd.Run()` and before `must(err)`. This runs in the outer host context (where `/sys/fs/cgroup` is accessible) after all child processes have terminated (so the cgroup directory is empty and removal succeeds). If the command failed, `must(err)` still receives and prints the error after cleanup. Stale cgroups on rerun are already gracefully handled by `os.IsExist(err)` check on `os.Mkdir`.
4. **Minimal Working Run Command for Sub-Task 6 / README:**
   `docker run --mount type=bind,source=./main.go,target=/root/main.go --name "containerdemo1" -h "containerhost" --privileged -i -d containerdemo:v1`
   (`--cap-add SYS_ADMIN` is redundant and can be dropped).

---

### 4. Dockerfile modernization (Ubuntu stays)
**Intent:** Remove the third-party PPA and make the build reproducible and leaner, while keeping Ubuntu, the Go toolchain, `ps`, `vim`, and the marker-file trick intact.

**Expected Outcomes**
- Base stays `ubuntu:24.04` (or the then-current LTS, verified at implementation time), pinned by digest.
- No PPA and no `software-properties-common`; Go is copied from the official, version-pinned Go image (`COPY --from=golang:<version>`), as decided.
- Fewer layers, `--no-install-recommends`, apt lists cleaned.
- `HOST-ROOT`, `CONTAINER-ROOT`, `/opt/container-filesystem`, `PS1`, and `WORKDIR /root` behave exactly as before.
- `docker build` / `podman build` both succeed.

**Todo List**
- [x] Pin the base image (tag plus digest).
- [x] Replace the PPA Go install with `COPY --from=golang:<pinned version> /usr/local/go /usr/local/go` and add `/usr/local/go/bin` to `PATH` (pin tag plus digest so Dependabot/Renovate can bump it). Verify that the copied Go toolchain runs on the Ubuntu 24.04 base.
- [x] Combine package installs into one `RUN`: `procps vim` with `--no-install-recommends`, then `rm -rf /var/lib/apt/lists/*`. Fix the trailing whitespace after `\`.
- [x] Keep the marker files and the `COPY ubuntu.tar` + `tar xf` into `/opt/container-filesystem`; delete the tar afterwards if it is not needed at run time.
- [x] Add `.dockerignore` (`.git`, `Documentation`, `Versions`, `*.md`); `ubuntu.tar` must stay in the build context.
- [x] Add `LABEL` metadata (source, description). No `USER` change: the demo needs root, noted in a comment.

**Relevant Context:** [`Dockerfile`](Dockerfile), [`.gitignore`](.gitignore).

**Status:** [x] done

**Implementation notes (for Sub-Task 5/6 and later):**
- **Base image and digest:** Ubuntu 24.04 is pinned using tag `ubuntu:24.04` and multi-arch index digest `sha256:68ee22004a9109b44973313b02ff7b1de250f1de0f5ecb628d73f579aaff33ac`.
- **Go version and digest:** Go 1.27.1 is copied from `golang:1.27.1` with multi-arch index digest `sha256:162be5298a40ed317005c8339c6de4d10d3eef336d66dc8e9259b03ab9d3a6d2`.
- **Apt package modernization:** Packages `procps`, `vim`, and `ca-certificates` are installed with `--no-install-recommends` in a single layered `RUN` command, followed by `rm -rf /var/lib/apt/lists/*` to clean up. Fixed the trailing whitespaces.
- **Marker files and tar:** Preserved `/HOST-ROOT` and `/opt/container-filesystem/CONTAINER-ROOT` markers exactly as before. Note: `ubuntu.tar` is kept inside `/opt/container-filesystem` because deleting it would alter the chroot's `/` folder contents seen by the presenter.
- **Dockerignore:** Created `.dockerignore` ignoring `.git`, `Documentation`, `Versions`, `*.md`, `createDemoContainer.sh`, `snippets.txt`, and `LICENSE` (while keeping `ubuntu.tar` in context).
- **Image Size Reduction:** Modernization reduced the image size from `1.54GB` to `880MB` (a reduction of 43% / ~660MB).
- **Hadolint check:** Verified using the official hadolint image via Docker. Warned about unpinned apt package versions (DL3008), which is acceptable for a demo setup.
- **Verification:** Built `containerdemo:v1` and verified hostname namespace isolation, marker files, go toolchain version, `ps`, `vim`, and the successful run of `main.go` (mounting `Versions/main8.go`).
- **Unverified:** Podman machine is not running on the macOS host; podman build is untested.

---

### 5. Script modernization
**Intent:** Make `createDemoContainer.sh` robust and runtime-agnostic.

**Expected Outcomes**
- Script fails fast on errors and no longer parses `docker ps` output.
- Works with Docker and Podman via one variable (`ENGINE=${ENGINE:-docker}`), without the manual "`--load` for podman" comment.
- Same resulting artifacts: `ubuntu.tar` and image `containerdemo:v1`.

**Todo List**
- [x] `#!/usr/bin/env bash` and `set -euo pipefail`.
- [x] Replace `run -d` / `ps | grep | cut` / `stop` / `remove` with `create` + `export` + `rm` (no running container needed to export a filesystem).
- [x] Add the `ENGINE` variable; apply `--load` only where it is needed (Docker with a non-default builder), documented in a comment.
- [x] Use a `trap` to remove the temporary container on failure.
- [x] Add a small `run-demo.sh` wrapping the long `docker run ...` command from the README (kept, as decided).
- [x] Run `shellcheck` on all scripts.

**Relevant Context:** [`createDemoContainer.sh`](createDemoContainer.sh), [`run-demo.sh`](run-demo.sh), run command in [`README.md`](README.md:16).

**Status:** [x] done

**Implementation notes (for Sub-Task 6/7 and later):**
- **Scripts:** [`createDemoContainer.sh`](createDemoContainer.sh) (builds `ubuntu.tar` + image `containerdemo:v1`) and the new [`run-demo.sh`](run-demo.sh) (starts container `containerdemo1`). Both are `#!/usr/bin/env bash`, `set -euo pipefail`, executable, and use `ENGINE="${ENGINE:-docker}"` for every runtime call. Usage: `./createDemoContainer.sh`, `./run-demo.sh`, or `ENGINE=podman ./createDemoContainer.sh` / `ENGINE=podman ./run-demo.sh`. `createDemoContainer.sh` does `cd` to its own directory, so it can be started from anywhere.
- **Final run flags (in `run-demo.sh`):** `$ENGINE run --mount type=bind,source=<abs path>/main.go,target=/root/main.go --name containerdemo1 -h containerhost --privileged -i -d containerdemo:v1`. `--cap-add SYS_ADMIN` is dropped (redundant, see Sub-Task 3). The source is an absolute path resolved with `"$(cd "$(dirname "$0")" && pwd)"` because relative `source=./main.go` is not portable. An old `containerdemo1` is removed first, so `run-demo.sh` can be re-run. The README still shows the old command; Sub-Task 6/7 should replace it with `./run-demo.sh` (and show the equivalent manual command with `--privileged` only). The attach hint printed is `$ENGINE exec -it containerdemo1 bash`.
- **Export:** `create --name ubuntusource -h ubuntusource ubuntu:24.04` + `export` + `rm -f` (via `trap cleanup EXIT`, which also runs once before `create` to clear a leftover from a failed run). Tag stays `ubuntu:24.04` without digest (as in the old script; the Dockerfile digest is not repeated to keep the script readable).
- **Tar difference (verified, none that matters):** `docker create`+`export` and the old `run -d`+`export` produce the same 3445 entries with identical names, modes, owners, sizes and symlink targets (only mtimes of runtime files such as `.dockerenv`, `dev/`, `etc/hostname|hosts|resolv.conf` differ; the files exist in both and are empty in both). `proc/` and `sys/` are empty directories in both. The tar checksums differ only because of those mtimes. The chroot demo is therefore unaffected, no short-lived start is needed.
- **`--load`:** not needed and removed. With the current builder (`default`, driver `docker`, containerd image store `overlayfs`), `docker build . -t containerdemo:v1` puts the image into `docker images` directly. `--load` would only be needed for a `docker-container` driver builder (not tested), and Podman does not use it. The script uses one engine-neutral build command with a one-line comment.
- **Verified (Docker 29.2.1, arm64 macOS):** shellcheck (`koalaman/shellcheck:stable`) clean for both scripts. `createDemoContainer.sh` exit 0 on a fresh run (image removed first), on a rerun, and with a stale `ubuntusource` container present; no `ubuntusource` left each time. With the Dockerfile temporarily moved away (forced build failure) the script exits 1 and the trap removes `ubuntusource`. `run-demo.sh` run twice: one `containerdemo1` is running, `--privileged`, hostname `containerhost`, `/root/main.go` is the bind mount and identical to `./main.go`. A temp container with `Versions/main8.go` as `/root/main.go` and the same flags ran `go run main.go run /bin/sh -c "hostname; ls /; ps"`: hostname `container`, `CONTAINER-ROOT` listed (host side shows `containerhost` and `HOST-ROOT`), `ps` shows PID 1 `exe`. All temp containers removed; `main.go` unchanged.
- **Not verified:** Podman (machine not running, `ENGINE=podman` is untested, including `create`/`export` behaviour and `build` without `--load`). Docker builders with the `docker-container` driver were not tested.
- **Note for tests of the repeated `go run`:** the demo's cgroup cleanup from Sub-Task 3 is unchanged and was not re-tested here beyond the main8 run succeeding.

---

### 6. Run-time flags
**Intent:** Reduce the privileges used to run the demo to what is actually needed.

**Expected Outcomes**
- README run command no longer uses the redundant flag combination; `--privileged` is dropped if testing shows it is not required.
- A short "Notes" section explains why root and `SYS_ADMIN` are required and recommends a disposable machine/VM.

**Todo List**
- [x] Test the demo with `--cap-add SYS_ADMIN` only; add the smallest extra options needed (for example `--security-opt` for seccomp/AppArmor, or `--cgroupns=private`) and record results per runtime.
- [x] Replace `--cap-add SYS_ADMIN --privileged` in the README with the verified minimum.
- [x] Mention rootless Podman limitations if observed.

**Relevant Context:** [`README.md`](README.md:16).

**Status:** [x] done

**Implementation notes (for Sub-Task 7 and later):**

#### Additional Flag Combinations Tested (Sub-Task 6)

Tested on Docker 29.2.1 (arm64 macOS, cgroup v2). These extend the Sub-Task 3 matrix with two new combinations not previously tried:

| Flags | Result | Root Cause |
|---|---|---|
| `--cap-add SYS_ADMIN --security-opt apparmor=unconfined --security-opt seccomp=unconfined --security-opt systempaths=unconfined` | **FAIL** | Gets past AppArmor (namespace creation works), but Docker still mounts `/sys/fs/cgroup` read-only; `cgroup.subtree_control` write panics with `read-only file system`. |
| `--cap-add SYS_ADMIN --security-opt apparmor=unconfined --security-opt seccomp=unconfined --cgroupns=host` | **FAIL** | Same root cause: `/sys/fs/cgroup` remains read-only without `--privileged`, regardless of cgroupns mode. |

**Conclusion:** `--privileged` is the minimum required flag. Docker mounts `/sys/fs/cgroup` read-only for any container not run with `--privileged`, and no combination of `--cap-add`, `--security-opt`, `--cgroupns`, or cgroup bind-mounts bypasses this on Docker 29 with cgroup v2.

#### README Changes Made

- **Run command:** `./run-demo.sh` is now the primary instruction; equivalent plain `docker run` command shown with `--privileged` only (dropped redundant `--cap-add SYS_ADMIN`) and `$(pwd)/main.go` as the absolute-path-safe source.
- **Notes section added** with: root/`--privileged` required (why), disposable machine advisory, tested runtime (Docker 29.2.1, cgroup v2, arm64 macOS), Podman untested/rootless unsupported, `createDemoContainer.sh` + `ENGINE=podman` mention.
- **Not touched:** references list, Reset section, Attach section, Show section (Sub-Task 7 scope).

#### What Sub-Task 7 should NOT duplicate

The README now has:
- A "Notes" section with: privilege rationale, tested runtime, Podman status, `createDemoContainer.sh` + `ENGINE=podman`.
- `./run-demo.sh` as primary run instruction with Podman variant noted.
- The equivalent plain `docker run` command.

Sub-Task 7 should expand the README with: prerequisites, `watch` command path (`/sys/fs/cgroup/containerdemo/pids.current`), build/attach/reset/troubleshooting steps, stale names fix — but should NOT re-add the privilege rationale or Podman note (already present).

---

### 7. Documentation cleanup
**Intent:** Remove stale names and make the README sufficient for a new presenter to run the show.

**Expected Outcomes**
- Names and paths consistent everywhere (`containerdemo`, `/sys/fs/cgroup/containerdemo`).
- README states prerequisites, supported runtimes, steps, reset, and troubleshooting (cgroup v2 only, `SYS_ADMIN` needed, macOS runs this inside the Docker VM).
- Snippets and notes match the code.

**Todo List**
- [x] Update [`README.md`](README.md): prerequisites (Docker or Podman, cgroup v2), build/run/attach/reset commands, troubleshooting, and "Further reading" (`pivot_root`, user namespaces, OCI runtime spec, `man 7 namespaces`, `man 7 cgroups`).
- [x] Fix "dockerdemo" and "max pods" in [`Documentation/BearNotes.md`](Documentation/BearNotes.md) (storyboard kept; snippets now point to `./createDemoContainer.sh` and `./run-demo.sh`).
- [x] Adapt the slide deck: new editable [`Documentation/Container in Go.pptx`](Documentation/Container%20in%20Go.pptx) (same 9 slides, updated content, speaker notes). The original `Container in Go.pdf` is kept unchanged; the user restyles the deck and exports a new PDF.
- [x] Normalise whitespace in [`snippets.txt`](snippets.txt) and re-check each "N to N+1" step against the `Versions` files.
- [x] Verify that the reference URLs in the README still resolve.

**Relevant Context:** [`README.md`](README.md), [`snippets.txt`](snippets.txt), [`Documentation/BearNotes.md`](Documentation/BearNotes.md), [`Documentation/Container in Go.pptx`](Documentation/Container%20in%20Go.pptx).

**Status:** [x] done

**Implementation notes (for Sub-Task 8):**
- **README:** Updated tagline to "Container in (about) 100 lines of Go demo". Added Prerequisites, Troubleshooting, Reset details (live mount pickup), cgroup watch check command (`watch -n 1 'cat /sys/fs/cgroup/containerdemo/pids.current'`), and Further Reading list (`pivot_root(2)`, `user_namespaces(7)`, `network_namespaces(7)`, `namespaces(7)`, `cgroups(7)`, `clone(2)`, OCI runtime spec).
- **Documentation:** `BearNotes.md` only had its stale names fixed (`containerdemo`, `/sys/fs/cgroup/containerdemo`, `max pids`) and its snippets point to the scripts. The deck was rebuilt as `Container in Go.pptx` (9 slides, speaker notes, no images); the user restyled it and exported a new `Container in Go.pdf`. An extra `Documentation/presentation.md` created by an earlier pass was deleted at the user's request.
- **Snippets:** Normalized tabs, removed stray indented `syscall.Chroot` lines from step 5-6 snippet, fixed whitespace/indentation across all sections, and ensured a final newline.
- **Diff verification:** Verified every N to N+1 snippet against consecutive diffs between `Versions/main(N).go` and `main(N+1).go`.
- **URL validation:** Verified all 12 referenced URLs resolve with HTTP 200 via `curl`.

---

### 8. CI and dependency hygiene (lightweight)
**Intent:** Catch breakage in the Go files, Dockerfile, and scripts automatically, and keep pinned versions current.

**Expected Outcomes**
- A GitHub Actions workflow runs on push and pull request.
- The pinned base image and Go version are kept current by Dependabot or Renovate.

**Todo List**
- [x] Add `.github/workflows/ci.yml` with: `gofmt -l` check, `go vet` and `go build` for `main.go` and for each `Versions/main*.go` individually (loop, because they share a package name), `shellcheck`, `hadolint`, and an image build (no run, since running needs elevated privileges).
- [x] Add `.github/dependabot.yml` (or `renovate.json`) limited to the Dockerfile and GitHub Actions.
- [x] Pin GitHub Actions to current major versions or SHAs, verified at implementation time.

**Relevant Context:** Remote is `git@github.com:mhenke1/containerdemo.git`. No `.github/` directory exists yet.

**Status:** [x] done

**Implementation notes:**
- **Workflow** [`.github/workflows/ci.yml`](.github/workflows/ci.yml): triggers `push` (branch `main`) and `pull_request`; `permissions: contents: read`; concurrency group `ci-<workflow>-<ref>` with `cancel-in-progress`. Three jobs on `ubuntu-latest`:
  - `go`: `actions/checkout`, `actions/setup-go` (`go-version-file: go.mod`), `test -z "$(gofmt -l main.go Versions)"`, then a bash loop (`set -euo pipefail`) running `GOOS=linux go vet` and `GOOS=linux go build -o /dev/null` on `main.go` and each `Versions/main*.go`.
  - `shell`: `shellcheck createDemoContainer.sh run-demo.sh` (preinstalled on the runner image; not verified on a real runner).
  - `docker`: hadolint via `hadolint/hadolint:v2.15.1` (pinned tag, config mounted from `.hadolint.yaml`), then `./createDemoContainer.sh` (creates `ubuntu.tar` and builds `containerdemo:v1`) and `docker image inspect containerdemo:v1`. The container is never run.
- **Action versions** (verified with `git ls-remote --tags`; `gh api .../releases/latest` returned 404 because `gh` is bound to a GitHub Enterprise host): `actions/checkout@v7` (latest tag v7.0.1), `actions/setup-go@v7` (latest tag v7.0.0). Major tags are used, not SHAs (optional per the task). Each use has a comment. The hadolint image tag `v2.15.1` was confirmed to exist and be the newest tag.
- **hadolint:** only finding is `DL3008` (unpinned apt versions). Ignored in a new [`.hadolint.yaml`](.hadolint.yaml) with a comment (base image is digest-pinned; pinning exact apt versions would break builds on every Ubuntu security update). The Dockerfile was not changed. A negative test (`FROM ubuntu:latest`) still reports DL3007, so the config does not disable linting in general.
- **Dependabot** [`.github/dependabot.yml`](.github/dependabot.yml): `github-actions` and `docker`, directory `/`, weekly. No `gomod` entry (no dependencies). A comment states that FROM and `COPY --from` support for the golang pin is not verified here, and that the `go` directive in `go.mod` must be bumped by hand together with the golang image tag.
- **No source files were changed** (Go files, scripts, Dockerfile, README, Documentation, `.gitignore`). `createDemoContainer.sh` was run locally, which regenerated the git-ignored `ubuntu.tar` and rebuilt `containerdemo:v1`.

---

## Decisions

1. **Go in the image:** `COPY --from=golang:<pinned version>` from the official Go image.
2. **Optional extras:** the `run-demo.sh` wrapper and the cgroup directory cleanup are both kept.

No open questions remain.

---

## Final notes

**Verified (locally, Docker 29.2.1, arm64 macOS, cgroup v2):**
- All 9 Go files: `gofmt -l` clean and `GOOS=linux go vet` / `go build` pass, individually.
- Cgroup v2 step (`pids.max`, cleanup) works with `docker run --privileged`; `--privileged` is the minimum on Docker 29 (matrix in Sub-Tasks 3 and 6).
- Dockerfile builds; image shrank from 1.54GB to 880MB; shellcheck and hadolint (with `.hadolint.yaml`) are clean; `createDemoContainer.sh` and `run-demo.sh` behave as described in Sub-Task 5.
- README reference URLs resolve (HTTP 200); `snippets.txt` "N to N+1" steps match the `Versions` diffs.
- CI files parse as YAML and `actionlint` reports 0 errors for `ci.yml`; every command in the workflow was run locally in equivalent form.

**Not verified:**
- **CI has not run on GitHub.** Runner-specific behaviour (preinstalled shellcheck, Docker on `ubuntu-latest`, `actions/*@v7` inputs) is unproven.
- **Dependabot** has not run; whether it updates the `COPY --from=golang:...@sha256` pin is unverified.
- **Podman** is untested everywhere (`ENGINE=podman` scripts, `podman build`, rootless).
- **Docker `docker-container` buildx driver** is untested (`--load` was removed on the basis of the default `docker` driver).
- The demo was only run on Docker Desktop for macOS (arm64); native Linux hosts and amd64 were not tested.
- The **slide deck layout** (`Container in Go.pptx`) was not checked visually by the agent.

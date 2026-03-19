# mvslovers Project Ecosystem — Root Context

This file provides shared context for all projects in the mvslovers ecosystem.
It lives in the parent directory of all project repositories.
Each project may have its own `CLAUDE.md` with project-specific details that
extend (never contradict) this root context.

---

## Project Ecosystem Overview

All projects target **MVS 3.8j running on Hercules**.
They are written in **C99** and/or **S/370 Assembler**, compiled and assembled
cross-platform (macOS / Linux host → MVS target).

### Projects and Dependency Graph

```
c2asm370        — GCC 3.2.3 fork: C → S/370 assembler cross-compiler (standalone)
crent370        — Standard C runtime + MVS extras (base dependency for ALL others)
ufsd            - Unix-like virtual filesystem server   needs: crent370
ufs370          — Unix-like virtual filesystem (legacy) needs: crent370
lua370          — Lua interpreter port                  needs: crent370
ftp370          — MVS FTP client                        needs: crent370
mqtt370         — MQTT utility + client library         needs: crent370
mqtt370-broker  — MQTT broker application               needs: crent370, mqtt370, lua370
mqtt370-cli     — MQTT command-line client              needs: crent370, mqtt370
zlib370         — zlib compression library port         needs: crent370
httpd           — HTTP server                           needs: crent370, ufsd(libufs), lua370
mvsmf           — z/OSMF REST API clone                 needs: crent370, ufsd(libufs), httpd
brexx370        - MVS version of bRexx
mbt             — MVS Build Tools (Python + Make)
```

### Repository URLs and mbt Migration Status

| Project        | Repository                                      | Build System | mbt Status        |
|----------------|------------------------------------------------|--------------|-------------------|
| c2asm370       | <https://github.com/mvslovers/c2asm370>         | autotools    | n/a (host tool)   |
| crent370       | <https://github.com/mvslovers/crent370>         | mbt          | done (v1.0.4)     |
| ufs370         | <https://github.com/mvslovers/ufs370>           | mbt          | done              |
| ufs370-tools   | <https://github.com/mvslovers/ufs370-tools>     | mbt          | in progress       |
| lua370         | <https://github.com/mvslovers/lua370>           | mbt          | done              |
| mqtt370        | <https://github.com/mvslovers/mqtt370>          | mbt          | done              |
| mqtt370-broker | <https://github.com/mvslovers/mqtt370-broker>   | mbt          | new, not yet pushed |
| mqtt370-cli    | <https://github.com/mvslovers/mqtt370-cli>      | mbt          | new, not yet pushed |
| zlib370        | —                                               | legacy       | not started       |
| httpd          | <https://github.com/mvslovers/httpd>            | mbt          | in progress       |
| ufsd           | <https://github.com/mvslovers/ufsd>             | mbt          | in progress       |
| mvsmf          | <https://github.com/mvslovers/mvsmf>            | mbt          | done (v1.0.0-dev) |
| ftp370         | <https://github.com/mvslovers/ftp370>           | legacy       | not yet pushed    |
| mbt            | <https://github.com/mvslovers/mbt>              | —            | active            |

---

## Target Platform Constraints — NEVER VIOLATE THESE

These are hard constraints. There are no exceptions. Do not suggest workarounds
that violate them, and do not introduce code patterns that assume a different
environment.

### Memory — Top Priority

**Memory efficiency and explicit memory management are the #1 priority.**
MVS 3.8j runs in a severely constrained memory environment.

- Always prefer stack allocation over heap allocation where safe
- Free all heap memory explicitly; no leaks, ever
- Avoid large static buffers; size them to the minimum required
- Avoid unnecessary string copies; use pointers into existing buffers
- When reviewing or writing code, always ask: "Can this be smaller?"

### Addressing

- MVS 3.8j is a **24-bit architecture** — all addresses must fit in 24 bits
- No 31-bit or 64-bit addressing
- No pointer arithmetic that assumes > 16 MB address space

### C Language

- **Strict C89 / ANSI C only** — compiled with GCC 3.2.3 (c2asm370)
- No C11, but gnu99 extensions
- No VLAs (variable-length arrays)
- **`-Wall` & `-Werror` is enforced** — all warnings must be resolved, never suppressed

### Character Encoding

- The MVS runtime operates in **EBCDIC** (CP037) — never assume ASCII
- No hardcoded ASCII character codes in logic (e.g. `c == 0x41` for `'A'`)
- Use character literals (`'A'`, `'\n'`) and let the compiler handle encoding
- String comparisons must be EBCDIC-aware; do not assume ASCII collating sequence

### Process Model

- **No `fork()`**, no `exec()`
- **No dynamic linking** — all code is linked statically via NCAL
- **No POSIX APIs**: no `pthread`, no `mmap`, no `sigaction`, no `dlopen`, etc.
- No standard Unix file paths (`/etc/`, `/tmp/`, `/usr/`, etc.)
  — use MVS dataset names configured via `.env`

### Stack

- Stack size is limited on MVS
- **No deep recursion** — use iterative algorithms or explicit stacks on the heap
- Be explicit about recursion depth when it is unavoidable

### Assembler

- Assembler is **IFOX00** (invoked via the alias `PGM=ASMBLR`)
- Not HLASM — do not use HLASM-only directives (`OPSYN`, etc.)
- All assembled modules must be **RENT** (reentrant) and **REUS** (reusable)
- Macro libraries: `SYS1.MACLIB`, `SYS1.AMODGEN`, `CRENT370.MACLIB`
  (additional MACLIBs configurable via `.env`)

---

## Build Pipeline

### Full Pipeline (mbt — C Projects)

```
make bootstrap     → resolve deps from GitHub Releases, allocate MVS datasets
make build         → c2asm370 cross-compile (.c → .s)
                   → upload .s to SOURCE PDS via mvsMF REST API
                   → submit multi-step JCL: IFOX00 (ASM) + IEWL (NCAL link)
                   → output: NCAL modules in {HLQ}.{PROJECT}.{VRM}.NCALIB
make link          → submit IEWL final linkedit JCL
                   → output: load module in {HLQ}.{PROJECT}.{VRM}.LOAD
make package       → TRANSMIT load library to XMIT, download to host
make install       → copy load module to install dataset(s)
```

### JCL Generation

JCL is generated from `string.Template` files in `mbt/templates/jcl/`.
Key templates:

- `asm-step.jcl.tpl` — per-module ASM + NCAL link step (batched N per job)
- `link.jcl.tpl` — final linkedit
- `alloc.jcl.tpl` — dataset allocation

Variables come from `project.toml`, not `.env`. Dynamic sections (SYSLIB
concatenation) are pre-rendered by helper functions in `mbt/scripts/mbt/jcl.py`.

---

## Configuration

### mbt Projects (current standard)

Project structure and build configuration live in `project.toml`.
Local settings go in `.env` (gitignored). See mbt CLAUDE.md for the
full config hierarchy (env → .env → global → defaults).

Key `.env` variables:

```sh
MBT_MVS_HOST=        # IP or hostname of the MVS system
MBT_MVS_PORT=1080    # mvsMF API port
MBT_MVS_USER=        # MVS userid
MBT_MVS_PASS=        # MVS password
MBT_MVS_HLQ=         # High-level qualifier for build datasets
MBT_MVS_DEPS_HLQ=    # HLQ for dependency datasets (default: MBTDEPS)
MBT_MVS_DEPS_VOLUME= # Volume for RECEIVE (MVS/CE users must set this)
```

The target system is **flexible** — it can be a remote TK4-, a local Hercules
with TK5, or MVSCE. The only requirement is IP connectivity to the mvsMF API.

---

## Project Directory Structure

### Standard Layout (mbt projects)

```
project-root/
├── .env                    # local config (gitignored)
├── .env.example            # config template (committed)
├── .gitignore
├── project.toml            # project definition (name, version, deps, build config)
├── VERSION                 # version file for release automation
├── Makefile                # includes mbt/mk/*.mk
├── README.md
├── CLAUDE.md               # project-specific context (extends this root CLAUDE.md)
├── mbt/                    # mbt submodule
├── include/                # public C headers
├── src/                    # C source files (.c) and generated ASM (.s)
├── asm/                    # hand-written S/370 assembler sources (.asm / .s)
├── contrib/                # dependency headers (managed by mbt bootstrap)
│   └── <dep>-<version>/
│       └── include/
├── .github/workflows/      # CI: build.yml (on PR), release.yml (on tag)
├── .mbt/                   # build state (gitignored): stamps, logs, lockfile
├── docs/                   # any kind of documentation (user guides, design docs, API references)
└── tests/                  # test scripts (API tests, integration tests)
```

---

## Dependency Management

### mbt Package Manager (active)

Projects using mbt declare dependencies in `project.toml`:

```toml
[dependencies]
"mvslovers/crent370" = ">=1.0.6"
```

`make bootstrap` resolves versions from GitHub Releases, downloads headers
and XMIT archives, receives NCALIB/MACLIB datasets on MVS. Dependencies
are cached in `~/.mbt/cache/` and tracked via `.mbt/mvs.lock`.

Each project produces release artifacts via CI (on tag push):

- `<project>-<version>-headers.tar.gz` — public headers for compile-time use
- `<project>-<version>-mvs.tar.gz` — XMIT archives of NCALIB/MACLIB for link-time use
- `package.toml` — machine-readable package metadata

### Legacy: contrib/_sdk (being phased out)

Some projects still use vendored `_sdk` submodules under `contrib/`
(e.g. `httpd_cgi_sdk`). These are being replaced by mbt dependencies
as projects migrate. **Do not add new `_sdk` repositories.**

---

## Git Workflow — MANDATORY

### Branching

- **Never commit directly to `main` or `master`**
- Every change (feature, fix, refactor, doc update) requires:
  1. A GitHub Issue describing the change
  2. A feature branch: `feature/short-description` or `fix/short-description`
  3. A Pull Request referencing the Issue
- Use `gh` CLI for creating Issues, branches, and PRs when appropriate

### Commit Messages

- Write clear, descriptive commit messages in English
- **Never mention AI, Claude, LLM, or any AI tool** in commit messages,
  code comments, or documentation — no exceptions
- Commit messages describe *what* and *why*, not *how it was generated*

### Example Workflow

```sh
gh issue create --title "Fix dataset list pagination" --body "..."
git checkout -b fix/dataset-list-pagination
# ... make changes ...
git add -p
git commit -m "fix: handle pagination in dataset list response"
gh pr create --title "Fix dataset list pagination" --body "Closes #42"
```

---

## Claude Behavior Guidelines

### Autonomous Actions (no confirmation needed)

Claude may run these without asking:

- Read-only filesystem operations: `ls`, `find`, `cat`, `grep`, `head`, `tail`, `wc`
- **Any read-only Bash command** with no side effects (e.g. `ls`, `pwd`, `which`,
  `file`, `tree`, `wc`, `diff`). These must never be blocked or require confirmation.
- File copies for inspection: `cp file /tmp/inspect`
- `git status`, `git log`, `git diff`, `git branch` (read-only git commands)
- `gh issue list`, `gh pr list`, `gh repo view` (read-only gh commands)
- Reading `.env.example`, `README.md`, `CLAUDE.md` files

### Confirmation Required Before Executing

- Any file modification or creation
- Any `git add`, `git commit`, `git push`, `git merge`, `git rebase`
- Any `gh issue create`, `gh pr create`, `gh pr merge`
- Running build commands that connect to MVS (`make build`, `make link`, etc.)
- Deleting files or directories
- Any command with side effects not listed above

### What Claude Should Never Do

- Suggest or write C99/C11 code — strict C89 only
- Use POSIX APIs (`pthread_*`, `mmap`, `fork`, `exec`, `signal`, etc.)
- Assume ASCII encoding for character data
- Suggest deep recursion or recursive solutions without explicit stack depth analysis
- Use standard Unix paths (`/etc/`, `/tmp/`, `/usr/`) in MVS code
- Reference AI or Claude in any user-facing artifact (comments, commits, docs)
- Commit to main/master
- Add new `_sdk` repositories or deepen the current contrib/ vendor approach
- Redesign JCL generation without explicit discussion

### What Claude Should Actively Propose (when appropriate)

- Issues and feature branches for any non-trivial change
- mbt migration for projects still on legacy build scripts
- Unified project structure for projects that diverge from the standard layout
- Per-project `CLAUDE.md` files that extend this root context
- Agent team configurations when a task naturally spans multiple projects
- Anything that reduces memory usage or allocation on MVS

---

## Testing

Testing is at an early stage. The reference implementation is in `mvsmf/tests/`.

- Tests are shell scripts using `curl` and `zowe` CLI against the live mvsMF API
- Tests go in `tests/` in each project
- Test scripts follow the same `.env` variable conventions as build scripts
- There is no host-side unit test framework yet

---

## mvsMF API

**mvsMF is both a project in this ecosystem and the tool used to build all projects.**

It provides a REST API compatible with z/OSMF for:

- Submitting JCL jobs and retrieving output
- Waiting for job completion and reading condition codes
- Dataset operations (read, write, allocate)

All build scripts (`mvsasm`, `mvslink`, etc.) communicate with MVS exclusively
through the mvsMF API. Direct FTP or TSO is not used in the build pipeline.

API connection parameters come from `.env` (see Configuration section above).

---

## Roadmap / Known Technical Debt

These are known issues to be addressed. When working in a project, consider
whether the current task is an opportunity to make progress on one of these.

| # | Item | Priority | Status | Notes |
|---|------|----------|--------|-------|
| 1 | mbt                         | High     | **done** | Core build system working. Used by crent370, ufs370, lua370, mqtt370, mvsmf, httpd. |
| 2 | mbt bulk-build              | High     | **done** | `make build` uses source upload + multi-step JCL batching. See design below. |
| 3 | c2asm370 optimizer bug      | High     | open | `-O1` generates `=V(*SYMBOL)` for `asm()`-named extern arrays with constant offset. See [c2asm370#3](https://github.com/mvslovers/c2asm370/issues/3). Workaround: `-O0`. |
| 4 | mbt volume auto-detection   | Medium   | open | Replace the `.env` VOLUME option for RECEIVE with auto-detection. See sketch below. |
| 5 | mbt TRANSMIT OUTDSN sizing  | Medium   | open | Pre-allocate OUTDSN for TRANSMIT based on source dataset size to avoid SB37 abends on large libraries. Requires [mvsmf#67](https://github.com/mvslovers/mvsmf/issues/67) (space attributes in dataset list API) first. |
| 21 | mbt dataset unit/volume support | Medium | open | Support `unit` and `volume` in `[mvs.build.datasets.*]` in project.toml for explicit device placement. Currently datasets are allocated without unit/volume, relying on system defaults. |
| 6 | lua370 mbt migration        | High     | **done** | Migrated and building with mbt. |
| 7 | mqtt370-broker finish       | High     | open | New repo, not yet pushed. Complete mbt integration and first build. |
| 8 | mqtt370-cli finish          | High     | open | New repo, not yet pushed. Complete mbt integration and first build. |
| 9 | Per-project `CLAUDE.md` files | Medium | partial | crent370, mvsmf, httpd have CLAUDE.md. Missing for ufs370, mqtt370, lua370, ftp370. |
| 10 | `.env.example` completeness | High | partial | mbt projects use project.toml + .env now. Review all projects for completeness. |
| 11 | Test framework | Low | open | Expand `mvsmf/tests/` pattern to other projects. |
| 12 | mbt incremental builds | High | **done** | SHA256-based change detection in `.mbt/stamps/` skips unchanged modules. |
| 13 | mbt `local_dir` enhancement | Medium | **done** | `c_dirs` and `asm_dirs` support multiple source directories. Used by httpd (`src/` + `credentials/src/`). |
| 14 | PDS COMPRESS via mvsMF | Medium | open | Investigate COMPRESS (IEBCOPY COPY INPLACE) as alternative to delete+reallocate. |
| 15 | httpd header refactoring | High | open | Split `httpd.h` into pure CGI interface and Lua scripting interface. Eliminates `-DLUA_USE_C89` for CGI consumers. |
| 16 | mbt link auto-include | Medium | open | Support `include = "*"` to automatically include all own NCALIB members. |
| 17 | mbt package: skip cache for app/module | Low | open | Only `library` and `runtime` packages need cache. |
| 18 | mbt install: absolute dataset names | Medium | open | Allow absolute DSNs for shared datasets like `HTTPD.LINKLIB`. |
| 19 | mvsmf mbt migration         | High     | **done** | PR #69 merged. First mbt-built release: v1.0.0-dev. |
| 20 | mbt LOAD BLKSIZE matching   | Medium   | open | LOAD dataset BLKSIZE must match target LINKLIB (e.g. HTTPD.LINKLIB=15040). Currently hardcoded in project.toml per project. Consider auto-detection or install-time reblock. |
| 22 | httpd mbt migration         | High     | **in progress** | project.toml, build (152 modules RC=0), link (13 modules). Open: lua370 LUA/LUAC exports, mvslink max_rc default. |
| 23 | mbt mvslink max_rc default  | Medium   | open | Final link should default to max_rc=0 (not 4). NCAL link (asm-step) keeps RC=4. |
| 24 | lua370 LUA/LUAC exports     | Medium   | open | lua370 exports LUA and LUAC (standalone programs with main). Causes IEW0241 doubly-defined warnings. Consider splitting lua370 into lib + cli, or removing from exports. |

### Volume Auto-Detection Sketch

```sh
#!/bin/bash
# mbt-volprobe - Auto-detect a usable volume for TSO RECEIVE
set -euo pipefail

BASE="http://localhost:1080/zosmf/restfiles/ds"
PROBE_DSN="IBMUSER.MBT.VOLPROBE"

# --- 1. Create temporary dataset ---
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  -u "IBMUSER:sys1" \
  -H "Content-Type: application/json" \
  -d '{"dsorg":"PS","alcunit":"TRK","primary":1,"secondary":1,"recfm":"FB","lrecl":80,"blksize":800}' \
  "${BASE}/${PROBE_DSN}")

if [[ "$HTTP_CODE" -ne 201 && "$HTTP_CODE" -ne 200 ]]; then
  echo "mbt-volprobe: failed to create probe dataset (HTTP $HTTP_CODE)" >&2
  exit 1
fi

# --- 2. Query volume ---
VOLUME=$(curl -s \
  -u "IBMUSER:sys1" \
  -H "Accept: application/json" \
  "${BASE}?dslevel=${PROBE_DSN}" \
  | jq -r '.items[0].vol // empty')

# --- 3. Cleanup ---
curl -s -o /dev/null -X DELETE \
  -u "IBMUSER:sys1" \
  "${BASE}/${PROBE_DSN}"

# --- Result ---
if [[ -z "$VOLUME" ]]; then
  echo "mbt-volprobe: could not detect volume" >&2
  exit 1
fi

echo "$VOLUME"
```

### Bulk-Build Design (Roadmap #2)

**Goal:** New `make bulk-build` target for projects with many modules (crent370: ~700,
lua370: ~200). Runs parallel to `make build` which stays as-is (inline JCL, single
module at a time, `--member` support).

**Problem:** `make build` inlines assembler source in JCL (`SYSIN DD *`). This causes:

- S80A/S878 abends on large `.s` files (mvsMF/HTTPD memory exhaustion)
- ~1400 JES jobs for crent370 (ASM + NCAL per module), ~45 min wall time

**Approach — two independent improvements:**

1. **Source upload instead of inline JCL**
   - New explicit dataset in `[mvs.build.datasets.source]` (RECFM=FB, LRECL=80)
   - Upload `.s` files as PDS members via mvsMF REST API (PUT per member)
   - JCL references `SYSIN DD DSN=...SOURCE(member),DISP=SHR` instead of `DD *`
   - Eliminates S80A regardless of source file size

2. **Multi-step JCL batching**
   - Bundle N modules per JES job as multi-step JCL
   - Each module = 2 steps: `ASMnn` (IFOX00) + `LNKnn` (IEWL NCAL)
   - Step names `ASM01`..`ASM99` + `LNK01`..`LNK99` → max 99 modules per job
   - Default batch size: **50 modules** (configurable in project.toml)
   - `COND=(4,LT,ASMnn)` per link step — failures don't block later modules
   - Collect and report all errors at end

**project.toml extension:**

```toml
[mvs.build.datasets.source]
suffix = "SOURCE"
dsorg = "PO"
recfm = "FB"
lrecl = 80
blksize = 3120
space = ["TRK", 600, 100, 200]

[build]
bulk_batch_size = 50   # modules per JES job, default 50
```

**New files in mbt:**

- `templates/jcl/bulk-asm.jcl.tpl` — multi-step ASM+NCAL template
- `scripts/mvsbulkasm.py` — bulk-build executor
- `mk/targets.mk` — new `bulk-build` target

**Pipeline:**

```
1. Cross-compile all .c → .s (same as make build)
2. Upload all .s to SOURCE PDS via mvsMF REST API
3. Generate multi-step JCL (batch_size modules per job)
4. Submit batch jobs, wait for completion
5. Parse per-step RCs, report failures
```

**`make build` stays unchanged** — inline JCL, one job per module, `--member`
support. Best for single-module iteration during development.

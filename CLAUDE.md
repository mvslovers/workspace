# mvslovers Project Ecosystem — Root Context

Shared context for all projects in the mvslovers ecosystem. Lives in the
parent directory of all project repositories. Each project has its own
`CLAUDE.md` with project-specific detail that extends (never contradicts)
this root context — keep this file only as large as necessary.

All projects target **MVS 3.8j on Hercules**, written in **C99 (gnu99)**
and/or **S/370 assembler**, built cross-platform (macOS / Linux host → MVS
target) with the **cc370** toolchain.

---

## Project Ecosystem

### Actively maintained

```
cc370    — GCC 3.4.6 fork: full host toolchain
           (cc370 compiler, as370 assembler, ar370 archiver, ld370 linker)
libc370  — Standard C library + MVS extras (base dependency for ALL targets)
ufsd     — Unix-like virtual filesystem server      needs: libc370
ufsd-utils — ufsd tooling / utilities
ftpd     — FTP server                               needs: libc370, ufsd(libufs)
httpd    — HTTP server                              needs: libc370, ufsd(libufs)
mvsmf    — z/OSMF REST API clone (CGI under httpd)  needs: libc370, ufsd(libufs), httpd(libhttpd)
mbt      — MVS Build Tools (Python + Make)
```

| Project | Build | Status |
|---------|-------|--------|
| cc370, libc370 | make | host toolchain |
| ufsd, ftpd, httpd, mvsmf | mbt v2 | migrated, building, CI green |
| mbt | — | active |

### Legacy / not maintained

No further work. Superseded: **c2asm370** → cc370, **crent370** → libc370.
Also unmaintained: ufs370, ufs370-tools, lua370, ftp370, mqtt370 (+broker,
+cli), zlib370, brexx370.

---

## Target Platform Constraints — NEVER VIOLATE

Hard constraints. No exceptions; do not suggest workarounds that violate them.

### Memory — #1 priority

MVS 3.8j is a severely memory-constrained environment.

- Prefer stack over heap where safe; free all heap explicitly — no leaks, ever
- Avoid large static buffers; size to the minimum required
- Avoid unnecessary string copies; use pointers into existing buffers
- Always ask: "Can this be smaller?"

### Addressing

- 24-bit architecture — all addresses must fit in 24 bits (≤ 16 MB)
- No 31-bit / 64-bit addressing; no pointer arithmetic assuming > 16 MB

### C language

- **C99 (gnu99) only**, compiled with **cc370** — no C11
- No VLAs
- `-Wall` & `-Werror` enforced — resolve all warnings, never suppress

### Character encoding

- The runtime is **EBCDIC (CP037)** — never assume ASCII
- No hardcoded ASCII codes in logic (e.g. `c == 0x41` for `'A'`); use character
  literals (`'A'`, `'\n'`) and let the compiler encode
- String comparisons must be EBCDIC-aware (no ASCII collating assumptions)

### Process model

- **No `fork()` / `exec()`**, no POSIX (`pthread`, `mmap`, `sigaction`, `dlopen`, …)
- Statically linked: **ld370** resolves the C runtime and dependencies by
  **autocall** from `.a` archives (no dynamic linking)
- No Unix paths (`/etc/`, `/tmp/`, `/usr/`) — use MVS dataset names from `.env`

### Stack

- Limited stack — no deep recursion; use iterative algorithms or explicit
  heap stacks. Be explicit about depth when recursion is unavoidable.

### Assembler & linker

- Assembler is **as370** (not HLASM — no HLASM-only directives like `OPSYN`)
- Linker is **ld370** (IEWL-compatible host linker)
- Assembled modules should be **RENT** (reentrant) and **REUS** (reusable)

---

## Toolchain & Build (mbt v2, cc370 host build)

The whole build runs **on the host** with the cc370 toolchain
(`cc370` → `.o`, `as370`, `ar370`, `ld370`). **MVS is touched only by
`make deploy`** (upload + RECEIVE the load library via the mvsMF REST API).

A project's `Makefile` is two lines (`MBT_ROOT := mbt` + `include
$(MBT_ROOT)/mk/mbt.mk`); everything else is in `project.toml`.

### make targets

```
make            Build the primary deliverable (library: archive; else: load modules)
make all        modules + library archive
make modules    production load modules only
make <name>     build one module (lowercase name, e.g. make httpd)
make lib        the static library archive
make test       build test modules
make deps       download + stage declared dependencies into .mbt/deps
make package    release artifacts in dist/ (load + lib tarballs)
make deploy     pack -> XMIT -> upload -> RECEIVE into the LINKLIB (touches MVS)
make doctor     check toolchain + MVS connectivity
make compiledb  write compile_commands.json for clangd
make clean      remove build/ dist/ (keeps staged deps)
make distclean  clean + remove all of .mbt/ (incl. deps)
make release / prerelease   version bump + git tag + GH release
make help       list targets

VERBOSE=1 make  echo full cc370/as370/ld370/ar370 commands
```

### Testing

```
make test       build test load modules
make test-host  build + run the dual (host+MVS) tests natively — fast inner loop
make test-mvs   build + deploy test modules + run the suite on the MVS target
make test-mvs ARGS="--only TSTX --only TSTY"   run only those tests
make check      every available suite (host + MVS)
```

- Declare each test as a `[[test]]` in `project.toml` (one TU, one `main()`).
- The only hard contract is the **return code** (0 = all passed; becomes the
  job step COND CODE). Use `#include <mbtcheck.h>` (`CHECK` / `CHECK_EQ` /
  `mbt_test_summary`) — portable C so a test runs both natively and on MVS.
- `make test-mvs` deploys to a separate `…TESTLIB` and prints a per-test
  pass/fail matrix (batch + TSO/IKJEFT01 step per test).
- Tests needing input DDs + pre-loaded members declare `[[test.fixture]]`.
- See `mbt/docs/testing.md` (and `mbt/docs/MIGRATION.md` for the v2 model).

---

## Dependencies (mbt v2)

Declare dependencies in `project.toml`, keyed `owner/repo` with a semver range:

```toml
[dependencies]
"mvslovers/ufsd" = ">=1.0.0-dev"
```

`make deps` resolves each range against the dependency's GitHub Releases,
downloads its `{repo}-{version}-lib.tar.gz`, and stages it under
`.mbt/deps/{repo}/` (`include/` + `lib/`). The build wires these in
automatically (`-I .mbt/deps/*/include` on compile, `.mbt/deps/*/lib/*.a`
autocalled on link). `libc370` is the cc370 **sysroot** (`-lc`), not a
declared dependency.

`make deps` writes **`mbt.lock`** (version + SHA256 per dep) at the project
root — **commit it** (source-of-record; `make clean`/`distclean` never touch
it). To develop against an unreleased dependency, use `.mbt/deps.local.toml`
(`[override]`, gitignored) — see `mbt/docs/MIGRATION.md`.

---

## Configuration (`.env`, for deploy)

Build is offline. `.env` (gitignored) holds the MVS connection used by
`make deploy` / `make doctor`:

```sh
MBT_MVS_HOST=        # IP or hostname of the MVS system
MBT_MVS_PORT=1080    # mvsMF API port
MBT_MVS_USER=        # MVS userid
MBT_MVS_PASS=        # MVS password
MBT_MVS_HLQ=         # HLQ for build/deploy datasets
MBT_MVS_DEPS_VOLUME= # volume for RECEIVE (MVS/CE users must set this)
```

The target system is flexible (remote TK4-/TK5, local Hercules, MVSCE) — the
only requirement is IP connectivity to the mvsMF REST API.

---

## Project Layout (mbt v2)

```
project-root/
├── project.toml        # name, version, type, deps, modules, build config
├── VERSION             # version string for release automation
├── Makefile            # two-line include of mbt/mk/mbt.mk
├── mbt.lock            # resolved dependency pins (committed)
├── .env / .env.example # MVS connection (.env gitignored)
├── mbt/                # mbt submodule
├── include/            # public C headers
├── src/                # C sources (.c)
├── asm/                # hand-written S/370 assembler (.asm / .s)
├── test/               # [[test]] sources (mbtcheck.h)
├── .github/workflows/  # build.yml (PR + push:main), release.yml (tags)
├── .mbt/               # build state + staged deps (gitignored)
├── build/ , dist/      # build outputs / release artifacts (gitignored)
└── docs/               # documentation
```

---

## Git Workflow

- Prefer a GitHub Issue + feature branch + PR for non-trivial changes; the
  PR references the Issue. Trivial submodule bumps / fixes may go direct to
  `main` when the maintainer asks.
- Commit messages: clear English, *what* and *why*. **Never mention AI,
  Claude, or any AI tool** in commits, code, or docs — no exceptions.
- Use the `gh` CLI for Issues/PRs.

---

## Claude Behavior Guidelines

**Autonomous (no confirmation):** read-only shell (`ls`, `find`, `grep`,
`cat`, `file`, `git status/log/diff`, `gh … list/view`), reading
`.env.example` / `README.md` / `CLAUDE.md`, copies for inspection.

**Confirm first:** file creation/modification/deletion; `git add/commit/push/
merge`; `gh issue/pr create/merge`; `make deploy` and anything else that
writes to MVS.

**Never:** assume ASCII; use POSIX APIs; suggest deep recursion without depth
analysis; use Unix paths in MVS code; reference AI/Claude in any user-facing
artifact.

**Actively propose:** Issues/branches for non-trivial work; per-project
`CLAUDE.md` files; anything that reduces memory use on MVS.

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
libc370  — Standard C library + MVS extras (base dependency for ALL targets - must be installed into hosts sysroot)
ufsd     — Unix-like virtual filesystem server          needs: libc370
ufsd-utils — ufsd tooling / utilities
ftpd     — FTP server                                   needs: libc370, ufsd(libufs)
httpd    — HTTP server                                  needs: libc370, ufsd(libufs)
mvsmf    — z/OSMF REST API clone (httpd server module)  needs: libc370, ufsd(libufs), httpd(libhttpd)
httplua  — Lua CGI handler (httpd server module)        needs: libc370, ufsd, httpd, lua370
httprexx — REXX Server Pages (httpd server module)      needs: libc370, ufsd, httpd
rexx370  — REXX interpreter, TSO/E V2 compatible        needs: lstring370
lua370   — Lua 5.4 engine: LUA/LUAC + liblua370.a       needs: — (sysroot libc only)
lstring370 — Reentrant length-prefixed strings          needs: — (sysroot libc only)
mbt      — MVS Build Tools (Python + Make)
```

**httprexx does not build against rexx370.** It resolves the IRX services
(`IRXINIT`/`IRXEXEC`/`IRXTERM`) at runtime against whatever is installed on the
system, and vendors only the headers under `include/`. So rexx370 is a runtime
prerequisite of a deployment, not a `[dependencies]` entry — do not add one.

**lstring370** declares no dependency by design either: consumers inject
`alloc`/`dealloc` through `struct lstr_alloc`, and the C runtime comes from the
cc370 sysroot (`-lc`). Consumed by rexx370 only — which is a separate project
from the unmaintained `brexx370` below, despite the name.

| Project | Build | Status |
|---------|-------|--------|
| cc370, libc370 | make | host toolchain |
| ufsd, ftpd, httpd, mvsmf, lstring370, httplua, httprexx, lua370 | mbt v2 | migrated, building, CI green |
| rexx370 | mbt v2 | building; no CI workflow yet |
| mbt | — | active |

### SMP4 FMIDs — assigned once, never reused

Products are installed through **SMP Release 4** (the SMP that ships with
MVS 3.8j, not SMP/E). A `[distribution]` table in `project.toml` makes
`make package` build the install package; **ufsd is the reference
implementation** — copy its block rather than inventing one.

A SYSMOD id is 7 characters and names a *functional level*: `T` + 3 letters +
version. That matches the form MVS 3.8j's own sysgen uses (`TMVS804`,
`TJES801`, `TIST801`, `TNIP800`, `TTSO801`) and stays clear of IBM's `H`/`J`
namespace. Service SYSMODs use `U`. One FMID per **minor** release; patches
ship as PTFs against it, and a new minor is a clean cut (RESTORE + REJECT the
old, then receive the new).

| Project | FMID | Service | State |
|---------|------|---------|-------|
| ufsd 1.2.x | `TUFS120` | `UUFS001…` | assigned in `project.toml` |
| ftpd 1.0.x | `TFTP100` | `UFTP001…` | proposed |
| httpd 4.0.x | `THTP400` | `UHTP001…` | proposed |
| mvsmf 0.1.x | `TZMF010` | `UZMF001…` | proposed |
| rexx370 1.0.x | `TRXX100` | `URXX001…` | proposed |
| nsf370 0.1.x | `TNSF010` | `UNSF001…` | proposed |

**Burned, do not reuse:** `TUFS110` (ufsd 1.1.x — never released, but applied
and accepted on a test system) and `TXPR100` (inline-delivery experiment,
received and rejected on `mvsdev`).

**Never `TMVS…`** — those are the MVS function SYSMODs of the sysgen.
libc370 and lstring370 get no FMID at all: they are statically linked and do
not exist on MVS.

**A test install must use a throwaway id.** A half-applied FMID leaves the
real one occupied, and you cannot check: the CDS stores hashed member names.
The SMPPTS *can* be listed (MCS member names are the documented exception) —
anything beyond that needs a `LIST SYSMODS` job.

### Legacy / not maintained

No further work. Superseded: **c2asm370** → cc370, **crent370** → libc370.
Also unmaintained: ufs370, ufs370-tools, ftp370, mqtt370 (+broker,
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
make package    release artifacts in dist/ (load + lib tarballs, + distribution)
make dist       re-render the SMP install package alone (needs [distribution])
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

## Live Debugging via HTTPD (httpd + module projects only)

**Applies to:** `httpd`, and projects whose deliverable is a module running
under it — `mvsmf`, `httprexx`, `httplua`. Not relevant to cc370, libc370,
ufsd, ftpd or mbt.

HTTPD ships display modules that read live MVS storage over HTTP. They are the
fastest way to answer "what does the control block actually say" without a dump,
and they are read-only. Use them **before** theorising about a control-block or
timing problem — a measured field beats a guess, and `docs/` can be stale (the
HTTPD block is 320 bytes today, not the 288 some docs still say).

| Endpoint | Shows |
|----------|-------|
| `/.dsrv?target=…` | Server control blocks, hex + a named field table |
| `/.dm?m=…` | Any storage address, hex + EBCDIC |
| `/.dmtt` | Master Trace Table (console log, raw) |

```
/.dsrv?target=HTTPD|MGR|FS                 no address needed
/.dsrv?target=MOD|TASK|FILE&m=<hex>        needs &m=
/.dm?m=<hex>&l=<bytes>&c=<chunk>&t=<title> l/c/t optional (c<=64)
/.dmtt
```

Chase a pointer by feeding it back into `/.dm`: `CVTPTR` lives at `0x10`, so
`/.dm?m=10&l=16` gets the CVT address, and `/.dm?m=<cvt+130>&l=8&t=CVTTZ` reads
the system timezone. That is how httpd#145 was pinned down instead of guessed.

**They are not registered by default.** In 4.0.0 nothing is active unless
`DD:HTTPDPRM` says so:

```
MOD=HTTPDSRV  /.dsrv
MOD=HTTPDM    /.dm
MOD=HTTPDMTT  /.dmtt
```

Also present, both superseded by mvsMF and only worth touching when working on
them: `MOD=HTTPDSL /dsl/*` (dataset lister) and `MOD=HTTPJES2 /jes/*` (JES
spool). `/jes/status` and `/jes/ddlist` return JSON and are handy as a quick
JES2 cross-check.

**Two cautions.**

A route's `auth` decides, and httpd's gate is not the only gate.
`?target=MOD` decodes the whole route block since httpd#146, so read `auth`
(`+14`), not `login` (`+09` — legacy, and labelled as such). Two values do not
mean what they look like: `AUTH=DEFAULT` is not "no authentication", it means
the route carried no `AUTH=` keyword and inherits the global `LOGIN` policy;
`resattr` 0 is the unset value `racf_auth()` reads as READ. And a route can be
`AUTH=NONE` and still answer 401 — `/zosmf/info` is public to httpd, its 401
comes from mvsMF's own auth track. Establish which layer answered before
debugging httpd's. `http_debug()` (`?debug=cgi`) decodes the same fields since
httpd#155, but as one line per route — reach for it to scan the whole table,
for `?target=MOD` to read one route's every byte.

Write curl flags out inline, never via a shell variable. zsh does not
word-split unquoted `$VAR`, so `A="-u u:p"; curl $A …` sends the userid with a
leading space and every request 401s while looking like a server fault. When an
authenticated request unexpectedly 401s, decode what was actually sent
(`curl -v … | grep Authorization`) before suspecting the server or a deploy.

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

## Agent Discipline

**Verification before fix.** For any bug fix: write a test that reliably
reproduces the failure first. Fix the code. Test must pass. "Feels fixed"
is not fixed — MVS bugs (codepage, EBCDIC boundaries, alignment) are
too subtle for that.

**Debugging sequence.** Read the full ABEND dump or error output before
proposing a fix. Reproduce the problem before attempting to correct it.
Change one variable at a time.

**Dependencies are permanent.** Every entry in `[dependencies]` is code
you don't control, updated on someone else's schedule. Prefer libc370 or
in-repo code before adding a dependency. If a new dep is added, document
the reason in the PR.

**Stop patterns.** Recognize and halt on:

- **Kitchen Sink** — asked to fix a faucet, renovating the kitchen. If the
  change touches code the user didn't mention, stop and ask.
- **Runaway Refactor** — one file becomes ten. Scope creep in a fix PR is
  a rollback risk on MVS.
- **Optimistic Path** — writing only for the happy case. MVS RC checking
  is mandatory; no silent error swallowing.
- **Confident Guessing** — "I think this works" is not information.
  "I'm not sure `__xmpost` handles key-0 client ECBs" is.

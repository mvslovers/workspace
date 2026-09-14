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

### SMP4 FMIDs — one per release, spent exactly once

Products are installed through **SMP Release 4** (the SMP that ships with
MVS 3.8j, not SMP/E). A `[distribution]` table in `project.toml` makes
`make package` build the install package; **ufsd is the reference
implementation** — copy its block rather than inventing one.

**The id is the release.** `T` + three product letters + the three version
digits: ufsd 1.3.0 is `TUFS130`, httpd 4.1.0 is `THTP410`. One id per
release, never re-spent, and each release's SYSMOD **deletes its
predecessor**:

```toml
[distribution.smp]
fmid   = "TUFS130"
delete = ["TUFS120"]      # the level this one replaces
```

**No version component may ever exceed 9.** There is no room in a 7-character
id for a second digit, so at patch 9 you cut the next minor and at minor 9 the
next major — 1.2.10 cannot be expressed and must not be released.

**`make release` does not move the id.** It bumps `VERSION` and the project
version and stops, so the tree comes out of a release carrying the id that was
just spent. Bumping `fmid` and `delete` is part of *preparing* the next
release; do it in the same commit that follows the bump, before anything is
built from that tree. Service
SYSMODs (`U…`) stay reserved and unused: mbt emits `++FUNCTION` only, there is
no `make ptf`, so a patch is a new function level, not a PTF.

Version numbers may skip in the id space and that is normal: ufsd 1.2.0, 1.2.1
and 1.2.2 all shipped under `TUFS120` when the rule was one id per *minor*, so
`TUFS121` and `TUFS122` are never assigned. Do not "fix" a gap.

**How DELETE works**, measured on mvsdev 2026-09-14 (HMASMP LVL 04.48, jobs
JOB00291 / JOB00293 / JOB00296–00299):

- SMP deletes the predecessor's LMODs from the target library
  (`HMA2240 SUCCESSFULLY DELETED LMOD …`) and then copies the new ones in
  (`HMA2380 COPY SUCCESSFUL … SYSMOD=<new>`). `MOD(x)` comes back carrying the
  new `FMID` and `RMID` — **element ownership transfers**.
- **Each zone is deleted by its own pass**: APPLY the CDS, ACCEPT the ACDS.
  Skip the ACCEPT and the old id survives as `REC APP ACC RGN` in the ACDS.
- A deleted id has no SMPSCDS backup entry, so the APPLY ends **RC 04** on
  `HMA2461 … NOT FOUND ON SMPSCDS LIBRARY` *after* reporting `HMA2270`
  success. mbt relaxes the ACCEPT gate to `COND=(4,LT,APPLY.HMASMP)` when
  `delete` is set, and leaves it strict otherwise.
- The predecessor is left as a tombstone — `TYPE = FUNCTION / DELBY = <new>` —
  which `LIST` reports at **RC 00**, so the "RC 04 + empty list = free" rule
  below reads it as occupied. That is correct: the id stays spent.

This replaces the `UCLIN` upgrade step entirely. `doc/uninstall.md` keeps its
UCLIN job for *removing* a product and for cleaning up a test install.

### The element-ownership wall

**SMP keys element ownership on `MOD(name)` in the CDS, not on the library the
element lives in.** A SYSMOD that does not own `MOD(x)` cannot install it: the
element summary prints

```
ELEM   ELEMENT   ELEM
TYPE   NAME      STATUS
MOD    FTPD      NOT SEL
```

nothing is copied, and everything else says success — RECEIVE / APPLY CHECK /
APPLY / ACCEPT all RC 00, `HMA2270 … SUCCESSFULLY COMPLETED`, `STATUS = REC APP
ACC` in both zones, and an empty target library. Measured twice: ftpd 1.1.0-dev
on mvsdev 2026-09-13, and again 2026-09-14 (JOB00291) where a *fresh, free*
FMID installing into a dataset unrelated to any other install still lost to the
owner of the module name.

The message that separates a real install from that one is
`HMA2380 COPY SUCCESSFUL - MOD=… - LMOD=… - LIBRARY=…`. **Verify every install
by listing the members of the target library**, never by the condition codes.

Two consequences:

- Versioning the product datasets never bought a clean cut between releases —
  the collision is on the module name in the inventory, not on the dataset.
- **A test install needs throwaway module names as well as a throwaway id.**
  A throwaway FMID alone measures this wall instead of whatever it meant to
  measure.

**`T` exists to stay out of IBM's namespace, and on MVS 3.8j that namespace is
`E??nnnn`** — measured on both MVS/CE and TK5: `EBB1102` is MVS 3.8j itself
(`TYPE=FUNCTION`, `STATUS=REC ACC RGN`), alongside `EAS1102`, `EBT1102`,
`EDE1102`, `EDM1102`, `EDS1102`, `EJE1103`, `EVT0108`, `ETV0108`. **Do not
move our ids to `E…`** — that is precisely the namespace being avoided.

| Project | FMID | Deletes | State |
|---------|------|---------|-------|
| ufsd 1.3.1 | `TUFS131` | `TUFS130` | assigned; 1.3.0 released 2026-09-14 under `TUFS130` |
| ftpd 1.1.0 | `TFTP110` | `TFTP100` | in `project.toml`, unspent — add `delete` |
| httpd 4.1.0 | `THTP410` | `THTP400` | in `project.toml`, unspent — add `delete` |
| mvsmf 1.0.1 | `TZMF101` | — | proposed (first level; 1.0.0 shipped with no `[distribution]`, so `TZMF010` was never assigned) |
| rexx370 1.0.0 | `TRXX100` | — | proposed (first level) |
| nsf370 0.1.0 | `TNSF010` | — | proposed (first level) |

**Burned, do not reuse:** `TUFS110` (ufsd 1.1.x — never released, but applied
and accepted on a test system), `TUFS120` (ufsd 1.2.0–1.2.2, `REC APP ACC` on
mvsdev), `TUFS130` (ufsd 1.3.0, released 2026-09-14), `TFTP100` (ftpd 1.0.x,
released), `THTP400` (httpd 4.0.x, `REC APP
ACC` on mvsdev), `TXPR100` (inline-delivery experiment, received and rejected
on `mvsdev`) and `TTST001`–`TTST004` (the `++VER DELETE` measurement,
2026-09-14).

**Never `TMVS…`** — MVS/CE carries applied USERMODs called `TMVS804`,
`TMVS816` and `TMVS817`, and TK5 does not carry them at all. That makes the
collision **distribution-specific**: you would find it on one system and miss
it on the other. The same holds for `TIST801`, `TJES801`, `TNIP800` and
`TTSO801` — all USERMODs on MVS/CE, absent on TK5.

libc370 and lstring370 get no FMID at all: they are statically linked and do
not exist on MVS.

**Status of the tooling.** Both halves have landed: `[distribution.smp] delete`
and the relaxed ACCEPT gate in **mvslovers/mbt#98**, and the unversioned
product dataset names in **mvslovers/ufsd#75** (ufsd is on 1.3.0-dev, FMID
`TUFS130`). ufsd is the worked example — copy its `[distribution]` block.
Still to adopt: **mvslovers/ftpd#143** and **mvslovers/httpd#269**; httpd
carries the dataset half separately in its #259/#267.

**A DELETE never touches the predecessor's data set, and this is the trap of
the rename.** SMP records the *ddname* an element was installed through and
never the data set behind it — the CDS `LMOD` entry reads `SYSTEM LIBRARY =
LINKLIB`. So a SYSMOD deleting its predecessor resolves that ddname in **its
own** job, deletes from the new library, and leaves the old data set populated,
working and still APF-authorised, with nothing in the job log naming it.
Measured on mvsdev 2026-09-14 (mvslovers/ftpd#145).

Two consequences for a project dropping the version qualifier:

- **Last qualifier unchanged** (`FTPD.V1R0M2.LINKLIB` → `FTPD.LINKLIB`, both
  `LINKLIB`): the install succeeds. Re-pointing `STEPLIB`/`IEAAPF00` and
  scratching the old libraries are then *the upgrade*, not housekeeping — skip
  them and the old server keeps running while every condition code says the
  upgrade worked. ufsd and ftpd are both this case.
- **Last qualifier changed**: APPLY CHECK fails RC 12 with `HMA2832 <dd> DDCARD
  MISSING` and the APPLY is skipped. It fails safely, but the shipped job needs
  a `//HMASMP.<olddd> DD` naming the old data set, which the generator cannot
  emit — `delete` is a list of ids and carries no DSNs. Filed as
  **mvslovers/mbt#100**.

**A DELETE leaves a tombstone in both zones**, even for an id that was never
installed: `TYPE = FUNCTION` / `DELBY = <new>`. `LIST` answers **RC 00** for it,
so the "RC 04 and an empty list means free" rule above has a third state — read
the stanza, not the return code. A plain `UCLIN … DEL SYSMOD(<old>)` clears it,
and a removal job should do so.

**Also open: mvslovers/mbt#99** — re-running a failed install skips APPLY CHECK.
`RECV` ends RC 08 on an already-received SYSMOD, `APPLYCHK` is bypassed by its
COND, and `APPLY`'s `COND=(0,NE,APPLYCHK.HMASMP)` names a bypassed step, which
JCL ignores. That is the recovery path, not an exotic one.

### Checking whether an id is free

```
//LIST    EXEC SMPAPP
//SMPCNTL  DD  *
 LIST CDS SYSMOD(TUFS120) .
/*
```

The zone operand is **mandatory** (`CDS` = applied, `ACDS` = accepted); bare
`LIST SYSMODS .` is SMP/E syntax and gets `HMA2033 SYNTAX ERROR`. **RC 04 with
an empty list means the id is free**; a hit prints `TYPE`, `STATUS`
(`REC`/`APP`/`ACC`) and the `FMID` it belongs to. A hit that prints only
`TYPE = FUNCTION` and `DELBY = <id>` is a deleted predecessor — it answers
**RC 00**, and it is spent, not free. Qualify it — `LIST CDS .`
dumps the entire inventory, 116 000 lines on MVS/CE.

`SYS1.SMPPTS` can also be listed directly, because MCS entry names are the one
documented unencoded case — but that shows only what was *received*. The CDS
and ACDS store hashed member names, so `LIST` is the only way to see what is
actually installed.

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
and they read nothing they should not — a measured field beats a guess, and
`docs/` can be stale — including this line, which claimed 320 bytes long after
the HTTPD block had grown to **392 (`0x188`)**. The struct's own trailer comment
in `httpd.h` says so; measure it there or with `?target=HTTPD` rather than
trusting any prose, this paragraph included.

**They were expensive until 2026-08-19, and on an older httpd they still are.**
Each display module is a separate load module that httpd re-LINKs per request,
and until `6448dd0` none of them set `__stklen` — so every `/.dm` or `/.dsrv`
hit demanded **262328 contiguous bytes** of subpool 0 against 65584 for an
ordinary CGI (mvslovers/httpd#196). Measured on mvsdev before that fix: 587
ordinary requests left the address space healthy, then two display calls, and
the next module load failed `IEA703I 106-0F` — insufficient *contiguous*
storage — killing every CGI on that HTTPD until `P HTTPD` / `S HTTPD`. Two
quarter-megabyte holes, fenced off, exactly the anvil mechanism of
mvslovers/httpd#195.

With `__stklen` set they cost what any CGI request costs, so on a current httpd
use them freely. **Check the build before leaning on them on an unfamiliar
stand**, and if one is old, treat a display call as a quarter-megabyte demand
rather than a free look.

One trap survives the fix: when a stand is already short of storage, the
instinct is to reach for `/.dmtt` to read the console log — the module that
renders the entire Master Trace Table, in the address space that is struggling.
Read the console another way.

And if you meet `HTTPD908E EXTERNAL PROGRAM … could not be loaded (not found in
STEPLIB?)`, **the parenthetical is a guess and it is often wrong.** The real
abend code sits in the `IEA703I` line next to it: `106-0F` is storage, not a
missing member. Check that before hunting a member that is present
(mvslovers/httpd#210).

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
`DD:HTTPPRM` says so:

```
MOD=HTTPDSRV  /.dsrv    AUTH=FORM
MOD=HTTPDM    /.dm      AUTH=BASIC
MOD=HTTPDMTT  /.dmtt    AUTH=BASIC
```

**Write the `AUTH=` — a route without one is public.** Since httpd#105 there is
no global `LOGIN` policy to fall back to, so a line reading just
`MOD=HTTPDM /.dm` hands anyone who can reach the port arbitrary storage reads,
and `/.dmtt` hands them the console log. That was already true whenever the
member set no `LOGIN`, which was the usual case; what #105 changed is that such
a route now *reads* `AUTH=NONE (public)` in `?target=MOD`, where `AUTH=DEFAULT`
used to require knowing the global policy to interpret. Measured on mvsdev
2026-08-22: both answered `200` unauthenticated.

Also present, both superseded by mvsMF and only worth touching when working on
them: `MOD=HTTPDSL /dsl/*` (dataset lister) and `MOD=HTTPJES2 /jes/*` (JES
spool). `/jes/status` and `/jes/ddlist` return JSON and are handy as a quick
JES2 cross-check.

**Two cautions.**

A route's `auth` decides, and httpd's gate is not the only gate.
`?target=MOD` decodes the whole route block since httpd#146, so read `auth`
(`+14`); `+09` is a reserved byte since httpd#105 retired the per-route `login`
flag with the global bitmask. Since that change `auth` holds four values and no
"unset" one — a route showing `AUTH=NONE` is public, whether the line said
`AUTH=NONE` or said nothing at all. The one line that reads public and is not
is `RES=` without `AUTH=`: a resource check needs an identity, so httpd resolves
that route to `BASIC` while parsing, and `?target=MOD` shows the `BASIC`.
`resattr` 0 is likewise the unset value `racf_auth()` reads as READ.

And a route can be `AUTH=NONE` and still answer 401 — `/zosmf/info` is public to
httpd, its 401 comes from mvsMF's own auth track. Establish which layer answered
before debugging httpd's.

**There is no `?debug=` query parameter any more.** `http_debug()` and its
`mod` / `vars` / `help` options were removed in httpd#225. It appended its dump
as a trailer to a response that had already been framed, so it could only ever
attach to a body whose length was *not* known in advance — display modules,
404s, error pages. Never a static file and never a mvsMF route: both set
`Content-Length`, and past that a client stops reading.

`?target=MOD` is the way to read the route table, and always was — `display_route()`
loops the whole array, one full field table plus hex per route.

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
- **After every commit, push or PR merge: update the project's `TODO.md`, if it
  has one.** Strike what landed, drop what the change made obsolete, and re-rank
  when the priorities moved. A `TODO.md` that lags behind `main` is worse than
  none at all, because it is read as current.

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

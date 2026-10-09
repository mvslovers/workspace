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
crypto370 — SHA-256, Blowfish, base64 (static library)  needs: — (sysroot libc only)
mbt      — MVS Build Tools (Python + Make)
```

**httprexx does not build against rexx370.** It resolves the IRX services
(`IRXINIT`/`IRXEXEC`/`IRXTERM`) at runtime against whatever is installed on the
system, and vendors only the headers under `include/`. So rexx370 is a runtime
prerequisite of a deployment, not a `[dependencies]` entry — do not add one.

**lstring370** declares no dependency by design either: consumers inject
`alloc`/`dealloc` through `struct lstr_alloc`, and the C runtime comes from the
cc370 sysroot (`-lc`). Consumed by rexx370 only — which is a separate project
from `brexx370` below, despite the name.

**crypto370** is SHA-256, Blowfish and base64, moved out of libc370 for 2.0
(libc370#244). Released as 1.0.0 on 2026-09-30; its headers are `sha256.h`,
`blowfish.h` and `base64.h` (libc370 called the last one `clibb64.h`). httpd
(all three) and mvsMF (base64) took it as a `[dependencies]` entry in their
libc370 2.0 ports (httpd 4.2.0-dev; mvsMF in mvslovers/mvsmf#379, 2026-10-01).
The functions keep their C names; the external names lost the `@@`
(`B64ENC`, not `@@B64ENC`).

**cc370 and libc370 versions go together.** libc370 2.1.x needs cc370
`>= 1.1.0, < 2` (every header `#error`s otherwise), and cc370 1.1.x needs libc370
`>= 2.1.0` (packages). Who owns what (compiler helpers and prologue macros are
cc370's), who needs which version, and the release checklists live in each repo:
libc370 `internals/releasing.md`, cc370 `internals/releasing.md`. **Read the one for the
project you release before cutting a release.**

### Maintenance mode

```
brexx370 — BREXX/370 REXX interpreter (JCC heritage)    needs: — (sysroot libc only)
```

**brexx370 gets no new features.** The work is limited to three things:
moving the build from JCC to mbt v2 / cc370 + libc370, one cleanup pass, and
the TSO integration (`ZMG0001`). New REXX function belongs in rexx370. A
brexx370 change outside that scope is a question for the maintainer, not a
judgement call.

| Project | Build | Status |
|---------|-------|--------|
| cc370, libc370 | make | host toolchain |
| ufsd, ftpd, httpd, mvsmf, httplua, httprexx | mbt v2 | migrated, building, CI green |
| lstring370 | mbt 3 | on mbt 3 since 2026-10-07 (lstring370#13) |
| lua370 | mbt 3 | on mbt 3 since 2026-10-07 (lua370#23; mbt.toml, no submodule), 41 of 42 outputs byte-identical to mbt 2 v2.2.0; ported to libc370 2.x in lua370#22, now 1.2.0-dev; CI green on main |
| crypto370 | mbt 3 (pilot) | new 2026-09-30; v1.0.0 released; first project on mbt 3 (mbt.toml, no submodule, crypto370#6, 2026-10-06), CI green; httpd and mvsMF depend on it since their libc370 2.0 ports |
| rexx370 | mbt v2 | building; no CI workflow yet |
| brexx370 | mbt v2 (migration branch) | maintenance mode; 59/65 REXX tests pass on MVS/CE, batch only |
| mbt | — | active |

### Product names

Decided 2026-10-09. A product has a **name** for people and a **repo name**
for machines, and each is used where it belongs:

| Product name | Repo | Notes |
|---|---|---|
| CC/370 | cc370 | the toolchain; its commands stay `cc370`, `as370`, `ld370`, `ar370`, `file370`, ... |
| LIBC/370 | libc370 | |
| MBT | mbt | |
| BREXX/370 | brexx370 | |
| LUA/370 | lua370 | |
| UFSD | ufsd | |
| FTPD | ftpd | |
| HTTPD | httpd | HTTPLUA and HTTPREXX are its modules (httplua, httprexx) |
| mvsMF | mvsmf | |
| (open) | rexx370 | to be named before its first release; **not** REXX/370, which is an IBM product name (as C/370 was IBM's compiler) |
| lstring370, crypto370 | the same | libraries with no presence of their own keep the repo name |

- **The product name** goes into prose, titles, book titles, web pages, README
  headings and release pages.
- **The repo name** stays in everything a machine reads: commands, paths,
  file names, data set qualifiers, `project.toml`, URLs, GitHub references.
  "CC/370 consists of cc370, as370, ld370 ..." is the distinction the rule
  exists for.
- **First mention per document: both**, as "CC/370 (cc370)", so a search for
  the repo name finds the page.
- A `CHANGELOG.md` keeps the names it was written with; it records history.

Moving to the names happens per repo, by the repo's session: the books and
web pages with their next change, README and release texts in a small PR of
their own. A project `CLAUDE.md` changes only where it quotes a name to the
outside.

### SMP4 FMIDs — one per release, spent exactly once

Products are installed through **SMP Release 4** (the SMP that ships with
MVS 3.8j, not SMP/E). A `[distribution]` table in `project.toml` makes
`make package` build the install package; **ufsd is the reference
implementation** — copy its block rather than inventing one.

**The id is the minor release** (decided for mbt 3, design §6.4). `T` + three
product letters + major + minor + `0`: ufsd 1.3.0 is `TUFS130`, httpd 4.1.0 is
`THTP410`. A patch is meant to become a **PTF** against its minor's FMID once
mbt builds PTFs. Until then a patch release needs an explicit `fmid` of its
own (1.4.1 as `TUFS141`), and the next minor an explicit `delete` naming that
id: deriving `TUFS140` there would leave `TUFS141` owning the modules, and SMP
installs nothing at RC 0 (the wall below). mbt 3 refuses to package in both
cases instead of guessing. Each id is spent once, never re-used, and each
release's SYSMOD **deletes its predecessor**. mbt 3 derives both from
`[smp] prefix` and the version; an explicit `fmid`/`delete` wins. The mbt 2
form, still in every `project.toml`:

```toml
[distribution.smp]
fmid   = "TUFS130"
delete = ["TUFS120"]      # the level this one replaces
```

**No version component may ever exceed 9.** There is no room in a 7-character
id for a second digit, so at patch 9 you cut the next minor and at minor 9 the
next major — 1.2.10 cannot be expressed and must not be released.

**Under mbt 2, `make release` does not move the id.** It bumps `VERSION` and
the project version and stops, so the tree comes out of a release carrying the
id that was just spent. Bumping `fmid` and `delete` is part of *preparing* the
next release; do it in the same commit that follows the bump, before anything
is built from that tree. Under mbt 3 the derived id follows the version by
itself; only an explicit `fmid`/`delete` needs that care. Service SYSMODs
(`U…`) stay reserved and unused until mbt builds PTFs: today it emits
`++FUNCTION` only.

Version numbers may skip in the id space and that is normal: ufsd 1.2.0, 1.2.1
and 1.2.2 all shipped under `TUFS120`, one id per *minor*, so `TUFS121` and
`TUFS122` are never assigned. Do not "fix" a gap.

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

This replaces the `UCLIN` upgrade step entirely. ufsd's `docs/uninstall.md` keeps its
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

**That generalises, and it cost three projects a day each.** A condition code
says whether a job ran, never whether the work happened — met three times
independently on 2026-09-14: the `NOT SEL` install above (RC 00, empty target
library); an upgrade whose `STEPLIB` was never re-pointed (every step RC 00,
old server still serving); and a multi-line IDCAMS scratch that deleted one of
six data sets and reported a single non-zero code (httpd, drnmig3a). Each time
the inventory answered correctly and the return code did not. **Read the
inventory — the member list, the `LIST` stanza, the startup banner.**

That IDCAMS run carries a trap of its own, and it belongs to the transport
rather than to IDCAMS: **`^` does not survive the mvsMF REST API.** `IF LASTCC
^= 0` arrives as `.=`, IDCAMS answers `IDC4229I INVALID RELATIONAL EXPRESSION`
and then discards the rest of the input stream — so every statement after the
bad card is skipped and the job reports one error instead of five omissions.
Write `NE`, and list afterwards (httpd, 2026-09-14).

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
| ufsd 1.4.0 | `TUFS140` | `TUFS130` | assigned, not yet checked on any stand; 1.3.0 released 2026-09-14 under `TUFS130`. `TUFS131` (1.3.1, never cut -- the libc370 2.0 port made the next release 1.4.0) is unspent and unassigned |
| ftpd 1.2.0 | `TFTP120` | `TFTP110` | assigned 2026-10-01 with the libc370 2.0 port (ftpd#157), now on `main`; free on the maintainer's word (only this project assigns `TFTP` ids), no `LIST` run on any stand; 1.1.0 released 2026-09-14 under `TFTP110`. `TFTP111` (1.1.1, never cut -- the libc370 2.0 port made the next release 1.2.0) is unspent and unassigned; it was free on mvsdev (`FMIDCHK JOB00332`) and drnmig3a (`FTPDCHK JOB00045`) |
| httpd 4.2.0 | `THTP420` | `THTP410` | assigned, not yet checked on any stand; 4.1.0 released 2026-09-14 under `THTP410`. `THTP411` (4.1.1, never cut -- the libc370 2.0 port, httpd#272, made the next release 4.2.0) is unspent and unassigned; it was free on mvsdev (`FMIDCHK JOB00343`) |
| mvsmf 1.2.0 | `TZMF120` | `TZMF110` | assigned 2026-10-01 with the libc370 2.0 port (mvslovers/mvsmf#379), now on `main`; not yet checked on any stand. 1.1.0 released 2026-09-14 under `TZMF110`, the first level (free on mvsdev, `JOB00360`, CDS and ACDS). `TZMF111` (1.1.1, never cut -- the libc370 2.0 port made the next release 1.2.0) is unspent and unassigned. 1.0.0 and 1.0.1 shipped with no `[distribution]`, so nothing below `TZMF110` was ever assigned |
| rexx370 1.0.0 | `TRXX100` | — | proposed (first level) |
| brexx370 (BREXX/370) 3.0.0 | `TBRX300` | — | proposed (first level). The prefix `TBRX` is BREXX/370's; the digits follow the release version, which is still open (`PARSE VERSION` shows `3.0.0-dev`, JCC builds showed `V2R5M3`). Not yet checked on any stand |
| nsf370 0.1.0 | `TNSF010` | — | proposed (first level) |

**Burned, do not reuse:** `TUFS110` (ufsd 1.1.x — never released, but applied
and accepted on a test system), `TUFS120` (ufsd 1.2.0–1.2.2, `REC APP ACC` on
mvsdev), `TUFS130` (ufsd 1.3.0, released 2026-09-14), `TFTP100` (ftpd 1.0.x,
released), `TFTP110` (ftpd 1.1.0, released 2026-09-14), `THTP400` (httpd 4.0.x,
`REC APP ACC` on mvsdev), `THTP410` (httpd 4.1.0, released 2026-09-14),
`TZMF110` (mvsMF 1.1.0, released 2026-09-14), `TXPR100` (inline-delivery experiment, received and rejected
on `mvsdev`), `TTST001`–`TTST007` (the `++VER DELETE` measurement and
the `REQ` semantics probe, both 2026-09-14) and `TTST008`–`TTST010` (the alias
measurement on mvsdev, 2026-09-27, mvslovers/mbt#112; afterwards removed from
both zones by UCLIN, `ALTCLN JOB00520` — spent all the same).

**Never `TMVS…`** — MVS/CE carries applied USERMODs called `TMVS804`,
`TMVS816` and `TMVS817`, and TK5 does not carry them at all. That makes the
collision **distribution-specific**: you would find it on one system and miss
it on the other. The same holds for `TIST801`, `TJES801`, `TNIP800` and
`TTSO801` — all USERMODs on MVS/CE, absent on TK5.

**Usermods to IBM modules: prefix `ZMG`, not `T`.** When a project patches IBM
elements (for example rexx370's TSO integration in IKJEFT01 and EXEC), it ships a
`++USERMOD` with `++VER … FMID(<the owning IBM FMID>)`, never a FUNCTION of its
own. `ZP…` is Greg Price's series, and `A`/`U`/`E`/`F`/`H`/`J` are IBM's.
`ZMG0001` is reserved for the BREXX TSO integration. `ZMG0002` is rexx370's TSO
integration: applied on MVSCE-LAB and not yet published (rexx370
`tso/usermod/`). Ship object decks only: SMP APPLY links them against the
*installed* load module (KB `MVS-SMP-0004`). RESTORE clears the inventory but
leaves CSECTs the usermod added in the load module (KB `MVS-SMP-0005`).

libc370, lstring370 and crypto370 get no FMID at all: they are statically linked and do
not exist on MVS.

**Status of the tooling.** Both halves have landed: `[distribution.smp] delete`
and the relaxed ACCEPT gate in **mvslovers/mbt#98**, and the unversioned
product dataset names in **mvslovers/ufsd#75**. ufsd is the worked example —
copy its `[distribution]` block. ftpd adopted both in **mvslovers/ftpd#143**
and httpd in **mvslovers/httpd#269**, the dataset half separately in its
#259/#267.

**A DELETE never touches the predecessor's data set, and this is the trap of
the rename.** SMP records the *ddname* an element was installed through and
never the data set behind it — the CDS `LMOD` entry reads `SYSTEM LIBRARY =
LINKLIB`. So a SYSMOD deleting its predecessor resolves that ddname in **its
own** job, deletes from the new library, and leaves the old data set populated,
working and still APF-authorised, with nothing in the job log naming it.
Measured on mvsdev 2026-09-14 (mvslovers/ftpd#145) with a throwaway module name
in libraries belonging to no product — **this is SMP's behaviour, not any one
project's**, so it transfers to every project in the ecosystem without a
per-project measurement. What does need checking per project is only which of
the two cases below it falls into.

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
  **mvslovers/mbt#100**. Neither ufsd nor ftpd is in this case; the first
  project to change a last qualifier will be, and **the failure is loud while
  the cause is not** — `HMA2832` names a ddname and says nothing about a
  renamed data set. Read this paragraph before renaming one.

**An APF entry is `dsname` *plus* volser, and the rename upgrade replaces one
rather than adding one.** A library that is present but sitting on a different
volume is there and not authorised: ufsd degrades quietly to SVC 244 where RAKF
permits it and does not start at all where it does not, and `UFSD007I` reports
which route it took (ufsd-measured). Two consequences once the old data set is
scratched: the new entry must *replace* the old, and an orphaned entry is more
dangerous after the scratch than before it, because a data set later allocated
under that name **on that volume** inherits the authorisation the entry still
grants. So an orphan left behind is worse than an old library left in place
(the volser pairing is measured; the orphan hazard is httpd's inference and has
not been measured).

**A DELETE leaves a tombstone in both zones**, even for an id that was never
installed: `TYPE = FUNCTION` / `DELBY = <new>`. `LIST` answers **RC 00** for it,
so the "RC 04 and an empty list means free" rule above has a third state — read
the stanza, not the return code. A plain `UCLIN … DEL SYSMOD(<old>)` clears it
— measured by httpd on drnmig3a 2026-09-14 (`TSTHCLN JOB00043`, 29 ×
`HMA2550`, COND 0000).

**They accumulate, one per upgrade, so a removal job must name every id the
product has ever spent.** A system that took two upgrades holds two tombstones;
deleting the release plus its immediate predecessor clears the newer and leaves
the older standing for good. Nothing reports that: the `LIST` answers only
about the ids it was given, and a surviving tombstone answers RC 00 while the
cleared ones answer RC 04, so it does not even lift the step's return code.
Write one `DEL SYSMOD(<id>)` per spent id in both zones. An id this system
never saw reports nothing to do, so the list needs no judgement about which
releases the system has seen — and that judgement is precisely what goes wrong.
ufsd's `docs/uninstall.md` is the worked example.

**Also open: mvslovers/mbt#99** — re-running a failed install skips APPLY CHECK.
`RECV` ends RC 08 on an already-received SYSMOD, `APPLYCHK` is bypassed by its
COND, and `APPLY`'s `COND=(0,NE,APPLYCHK.HMASMP)` names a bypassed step, which
JCL ignores. That is the recovery path, not an exotic one.

**Aliases travel as `TALIAS`, or not at all.** A load module's aliases
(`aliases = [...]` on `[[module]]`, mbt#113) reach the LKLIB as true aliases,
but a `++MOD` without `TALIAS(…)` makes SMP copy the main member only: target
library and DLIB end up without a single alias, and every step reports CC 0000
(`TTST008`, JOB00509). With `TALIAS` on the `++MOD` — the JCLIN stays COPY —
SMP installs true aliases into both libraries, re-binds nothing (`AC=1` and
`norent` survive) and records `TALIAS = …` on the MOD entry in both zones
(`TTST009`, JOB00515/00516). An upgrade with `DELETE` moves them onto the new
module; all three names ran the new code (`TTST010`, JOB00518/00519). mbt emits
`TALIAS` since **mvslovers/mbt#114**. **Not measured: a release that drops an
alias** — APPLY deletes only the LMOD in the target library (ACCEPT deletes
module and aliases in the DLIB), so a dropped alias most likely survives there,
pointing at the deleted module. **mvslovers/mbt#115**; read it before removing
an alias from a shipped product.

**Name the stands, with job numbers, every time an id is reported free.** One
stand is not enough — the `TMVS…`/`TIST801` collisions below are applied on
MVS/CE and absent on TK5, so a single check finds them on one system and misses
them on the other. And coverage that is inferred from a neighbouring row goes
wrong in both directions: a row that silently covers one stand where the row
above covered two reads as equally thorough (ftpd, 2026-09-14), and a stale
"one stand only" note understates coverage and holds back a release that was
ready (httpd, same day). Neither was written untruthfully; both are invisible
without job numbers.

### `REQ` is an AND, so it cannot express a version floor

**Measured on mvsdev 2026-09-14** (job `TZMFREQ`, throwaway ids `TTST005`–
`TTST007`, APPLY CHECK only, all three REJECTed afterwards). Three SYSMODs
carrying nothing but a `++VER`:

| `REQ` | APPLY CHECK |
|---|---|
| `REQ(THTP410)` — installed | **CC 0000** |
| `REQ(TZZZ999)` — absent | CC 0012 |
| `REQ(THTP410,TZZZ999)` | **CC 0012** |

```
HMA3022 ** APPLY PROCESSING TERMINATED FOR SYSMOD TTST007
        - REASON = MISSING/NOGO REQUISITES:
HMA3590     --- TZZZ999 REQ
```

A present requisite does not satisfy a list that also names an absent one:
`REQ` is **conjunctive**. So the tempting shape — name every level of a
dependency you can work with, `REQ(THTP410,THTP411,…)`, and add the next one
each release — demands **all of them installed at once**, which one-id-per-
release makes impossible: `THTP410` itself carries `DELETE VER(001) = THTP400`.
Such a list makes the product uninstallable everywhere.

There is no range syntax either, so `REQ` can only ever say *"exactly this
level"*. That fails in both directions for a dependency that moves: an older
level does not satisfy it, and a system where a **newer** one was installed
fresh never saw the id being named.

**So a version floor on another product belongs in the installation guide, as
prose.** Every project in the ecosystem declares `prereq = []` and says so in
its docs — httpd on UFSD, mvsMF on httpd. `REQ` remains right only for a
genuinely fixed co-requisite that will not move.

Two things the probe also settled: a `++FUNCTION` with no elements is received
without complaint (`HMA3971 … HAS NO ELEMENTS` is a warning, `HMA3930
SUCCESSFULLY RECEIVED` follows), so a requisite question needs no throwaway
module names — the APPLY CHECK fails long before elements matter. And `REJECT`
does clean a received-but-never-applied id out of the inventory (`HMA2270`,
then `LIST` reports RC 04 not found) — but the id stays **burned** all the
same, exactly as `TXPR100` did.

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
+cli), zlib370.

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

## Three libraries, three owners — the deploy convention

Now that products install through SMP, **`<PROD>.LINKLIB` belongs to SMP and
nothing else may write to it.** A `make deploy` into that library leaves the
inventory describing a level that is not on disk, and SMP cannot notice.

So each project deploys into a development library of its own,
`<PROD>.DEV.LINKLIB`. **Under mbt 3 that is the default**: `mbt.toml` writes
`[deploy] target` only for another library, or when the project name is
longer than a qualifier's 8 characters. In that case mbt refuses to guess a
shortened name (`is not a valid dataset name … -- set [deploy] target`), since
a started task's STEPLIB has to name the library. An mbt 2 `project.toml`
still names it, because mbt 2's default was `{HLQ}.{PROJECT}.{VRM}.LINKLIB`:

```toml
[deploy]
target = "MVSMF.DEV.LINKLIB"
```

| Library | Owner | Filled by |
|---|---|---|
| `<PROD>.LINKLIB` | SMP | the install job, and only that |
| `<PROD>.DEV.LINKLIB` | development | `make deploy` |
| `HTTPD.LINKLIB` | httpd | httpd's own install |

**The DEV name carries no HLQ on purpose.** For a development level to be
reachable it has to be named in a started task's STEPLIB, and a procedure can
only name a fixed data set — a per-developer HLQ would need a per-developer
STC. Anyone sharing a server shares the running level anyway, so the isolation
the old `{HLQ}.{PROJECT}.{VRM}.LINKLIB` gave was only ever in the staging step,
never where it mattered.

**Put DEV first in the concatenation**, ahead of the SMP library. Whichever
comes first wins, so that makes a deploy override the installed level — and
removing the DD goes back to it. The same rule is why a copy of a module placed
into another product's library by hand is a trap: it shadows both, and an
install into the right library then activates nothing while every step reports
success.

**Every library in an authorized STEPLIB concatenation must be APF-authorized**
— one that is not silently de-authorizes the whole task, and the failure that
follows does not name the cause. So a DEV library needs its own `IEAAPF00`
entry beside the SMP one, with the volume the allocation actually used (the
alloc template's bare `UNIT=SYSDA` is `mbt#102`). MVS 3.8j reads `IEAAPF00` at
IPL and has no dynamic APF, so adding either needs one — do both at once.

**A DEV library has no business on a production system.** Sitting first in a
concatenation, it silently runs a development build; `?fn=version` (or the
equivalent) is the check.

Note the deploy still needs its activation step today: `make deploy` DELETEs
the target library before the RECEIVE (NJE RECEIVE will not merge), which
cannot work on a library a running server holds. Merging the member instead
would let a deploy activate by itself — no IEBCOPY, no restart — and is
**`mbt#105`**.

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
├── docs/               # documentation for USERS (manuals, guides)
└── internals/          # documentation for MAINTAINERS (design, measurements)
```

### Documentation: `docs/` is for users, `internals/` for maintainers

Decided 2026-10-04. The directory name says who the text is for:

| Directory | Reader | Holds |
|---|---|---|
| `docs/` | someone **using** the product | the manuals (`docs/books/`), installation and configuration guides, later man pages |
| `internals/` | someone **working on** the product, sessions included | design notes, format analyses, measurements, release checklists, roadmaps |

**Not `doc/` beside `docs/`.** One letter apart, a file filed under the
wrong one goes unnoticed, and "see the docs" in prose cannot say which tree
it means. A project still holding a `doc/` moves it to `internals/`.

The test is the reader, not the polish: `releasing.md` is carefully kept and
still internal; a configuration guide for a user is `docs/` even as a
draft. When a piece of `internals/` turns out to be what a user needs (a
format description, say), it moves into a manual rather than being linked
from one.

**Moving is one small PR of its own** per project, never folded into other
work: `git mv`, then every reference found by `git grep -n 'docs/'` (and
`'doc/'`) — CLAUDE.md, READMEs, `TODO.md`, code comments, workflow files —
rewritten in the same PR. A `CHANGELOG.md` keeps its old paths; it records
history.

The manuals are set with the `mvslovers/bookmaster` template (a submodule at
`docs/books/bookmaster`) and numbered `ML<area>-<serial>-<edition>`.

**One area per product, assigned up front** (decided 2026-10-07), so a
number never depends on the order in which books get written. Within an
area, serial 0001 is the guide and 0002 the reference; further volumes count
on. The edition is the last digit: `-0` the Draft, `-1` the first edition.
A product not in the table gets an area only when its first book starts --
add the row before the first commit. The registry is the README of
`mvslovers/bookmaster` ("Document numbers"); the table below mirrors it.

| Area | Product | Books |
|---|---|---|
| ML01 | CC/370 + LIBC/370 (released as a pair) | 0001 CC/370 User's Guide, 0002 CC/370 Command Reference, 0003 LIBC/370 Programmer's Guide, 0004 LIBC/370 Library Reference -- on `main`, Draft |
| ML02 | MBT (v3 only) | 0001 guide, 0002 reference -- planned |
| ML03 | BREXX/370 | 0001 User's Guide, 0002 Reference, 0003 Library and Samples (RXLIB, samples) -- in preparation |
| ML04 | rexx370 | planned |
| ML05 | UFSD | planned |
| ML06 | FTPD | planned |
| ML07 | HTTPD, with its modules | 0001/0002 HTTPD; HTTPREXX and HTTPLUA from 0003 -- planned |
| ML08 | mvsMF | planned |

How the books live, build and ship (agreed 2026-10-07 by the cc370 and
libc370 sessions): on `main` beside the code, updated in the PR that changes
the documented behaviour; built by CI on every PR (typst pinned by version
and sha256); attached to every release with their `SHA256SUMS` lines; a
books step in each project's `internals/releasing.md`. The repo's session
owns its books, and a second session cross-reads every change. cc370 #893
and libc370 #477 are the worked examples.

**A product with both books and a Read the Docs site keeps the two in step**
(decided 2026-10-07; brexx370 has a Sphinx site today, libc370 will get
one). A change to documented behaviour updates the book *and* the Sphinx
source in the same PR, and the cross-reader checks both against each other
as well as against the code. This is double maintenance and a drift risk
by construction, so it stands only until one source can feed both; the
candidate is Typst's HTML export from the book sources (experimental in
typst 0.15), published to Read the Docs through a custom build.

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

Write curl flags out inline, never via a shell variable — see **Agent
Discipline** for the general rule and what it has cost. The httpd-specific
consequence: when an authenticated request unexpectedly 401s, decode what was
actually sent (`curl -v … | grep Authorization`) before suspecting the server or
a deploy.

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
- **`CHANGELOG.md` and the GitHub release page are written for someone who
  has never heard of this ecosystem.** No consumer project names (ufsd, ftpd,
  httpd, mvsMF, brexx370, …) and no job numbers or system names from the
  maintainer's private systems (`JOBnnnnn`, mvsdev, MVSCE-LAB, …): describe
  the effect in the project's own terms ("a server thread", "measured on MVS:
  18/18, previously 11"). Those references belong in issues, PRs and commits.
- **Every release reworks its release page before it is announced.** The
  workflow pastes the CHANGELOG section; turn it into a page for a new user:
  a lead paragraph (what the release is, whether it is a drop-in, the
  toolchain range), "Read this first" for what a caller notices, a
  before/now table of the fixes, how to install, then the full changelog.
  Check the result for the two rules above.

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

**The measurement survives; the sentence beside it does not.** Twenty-seven
instances across three days of one shape: a figure checked exhaustively, and the
one-line claim written next to it checked not at all — "it is in the PR body"
(it was not), "absent from our deck" (the tool had printed a delete *and* an
insert), "no new machinery is needed" (two of three kinds, not three). **Not one
was caught by its author re-reading it**, including the two authors who knew the
shape by name and had written it down that same day. So the defence is not
vigilance and "check your claims" adds nothing.

What works is structural: **a number may be published by whoever measured it; the
sentence beside it is read by someone who did not produce the number.** Where two
sessions are working the same problem, that is what the division is for. Where
there is only one, the substitute is to re-derive the claim from the artefact
rather than from memory of it — open the file, grep the source, run the filter —
because the claim and the measurement fail independently.

**And cross-reading cannot catch a frame both readers are inside, so re-read the
deliverable before refining a rule meant to satisfy it.** Two sessions spent six
hours checking the definition of a clause that the issue excludes in its own
first bullet — each auditing the other's arithmetic, which is precisely the
activity that feels like checking. Every earlier instance was caught by the other
party; this one was not, and could not be.

Two corollaries met repeatedly: **a difference between two tools is not a cause
until a filter replaces the subtraction**, and **two statistics of one dataset
pointing opposite ways is not a contradiction** — it usually says the aggregate
is carried by a few large members. Write both down.

**The shell is an instrument too, and it fails by answering.** Write flags out
inline, never through a shell variable: **zsh does not word-split an unquoted
`$VAR`**, so `M="-I a -I b"; tool $M …` hands the program *one* argument and the
program usually carries on. Met four times on 2026-09-17 across two sessions —
`curl $A` sending the userid with a leading space and 401ing like a server fault;
`as370 $MACFLAGS` receiving one giant `-I`, finding no macro at all, **exiting 0**
and writing a deck whose section lengths were wrong by −6 and −96. Those numbers
were a keystroke from being reported.

**The same command works in a script and fails when pasted**, because `#!/bin/sh`
*does* split — which is what makes it confusing rather than obvious: the gate's
own worker was correct and the line typed beside it was not.

A wrapped command lies the same way. `ls` aliased to a long-format lister turned
`ls "$SRC" | sed …` into a module list of 5,528 *listing lines*, and `xargs -n 1`
then ran 38,696 times on their fields. **Confirm a count against a known answer
before building on it**, and prefer `find`, `git ls-files` or a glob to `ls` in a
pipeline.

The rule behind all four: **these do not crash, they answer.** Exit 0 and a
plausible number is the whole failure mode, so the defence is a control you
already know the value of — not care.

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

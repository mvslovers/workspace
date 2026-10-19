# SMP 4 install packages, FMIDs and what SMP really does

Read before cutting a release, editing `[distribution]`/`[smp]`, or running any SMP job.
Moved verbatim from the root CLAUDE.md on 2026-10-19. Facts measured here and not yet in the KB
are ingest candidates (`knowledge/inbox/`).

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
| ufsd 1.5.0 | `TUFS150` | `TUFS140` | derived by mbt 3 on main (1.5.0-dev), not yet checked on any stand. 1.4.0 released 2026-10-13 under `TUFS140`, installed 2026-10-13 on m38r (JOB00362/363), m38b (666/667), m38l (1672/1673), m38x (593/594) (++VER DELETE(`TUFS130`) only: a stand still on `TUFS120` needs the UCLIN of ufsd `docs/uninstall.md` step 2 first, see the 1.4.0 release page). `TUFS131` (1.3.1, never cut -- the libc370 2.0 port made the next release 1.4.0) is unspent and unassigned |
| ftpd 1.3.0 | `TFTP130` | `TFTP120` | derived by mbt 3 on main (1.3.0-dev), not yet checked on any stand. 1.2.0 released 2026-10-13 under `TFTP120`, installed 2026-10-13 on m38r (JOB00366, via 1.1.0), m38b (671, via 1.1.0), m38l (1675), m38x (596) (++VER DELETE(`TFTP110`) only: a stand still on `TFTP100` needs 1.1.0 first); `TFTP120` was free on the maintainer's word, no `LIST` run on any stand. 1.1.0 released 2026-09-14 under `TFTP110`. `TFTP111` (1.1.1, never cut -- the libc370 2.0 port made the next release 1.2.0) is unspent and unassigned; it was free on mvsdev (`FMIDCHK JOB00332`) and drnmig3a (`FTPDCHK JOB00045`) |
| httpd 4.4.0 | `THTP440` | `THTP430` | derived by mbt 3 on main (4.4.0-dev), not yet checked on any stand. 4.3.0 released 2026-10-15 under `THTP430` (libc370 2.12.1, the httpd#297 / mvsmf#430 leak fix), installed 2026-10-15 on m38r (JOB00891), m38l (1708), m38x (629), m38b (1517), each verified by member list and `LIST` (`THTP430` REC APP ACC, `THTP420` DELBY tombstone); `THTP430` was free on the maintainer's word, no `LIST` run before the release. 4.2.0 released 2026-10-13 under `THTP420`, installed 2026-10-13 on m38r (JOB00372, via 4.1.0), m38b (677, via 4.1.0), m38l (1680), m38x (601) (++VER DELETE(`THTP410`) only: a stand still on `THTP400` needs 4.1.0 first); `THTP420` was free on the maintainer's word, no `LIST` run on any stand. 4.1.0 released 2026-09-14 under `THTP410`. `THTP411` (4.1.1, never cut -- the libc370 2.0 port, httpd#272, made the next release 4.2.0) is unspent and unassigned; it was free on mvsdev (`FMIDCHK JOB00343`) |
| mvsmf 1.4.0 | `TZMF140` | `TZMF130` | derived by mbt 3 on main (1.4.0-dev), not yet checked on any stand. 1.3.0 released 2026-10-15 under `TZMF130` (libc370 2.12.1, the #430 leak fix), installed 2026-10-15 on m38r (JOB00892), m38l (1709), m38x (630), m38b (1518), each after HTTPD 4.3.0 and with HTTPD stopped around the install, then `LIST`-verified on all four (`TZMF130` REC APP ACC, `TZMF120` DELBY tombstone); `TZMF130` was not `LIST`-checked before release. 1.2.0 released 2026-10-13 under `TZMF120`, installed 2026-10-13 on m38r (JOB00374), m38b (680), m38l (1677), m38x (598) (needs HTTPD 4.2.0 installed first, mvsmf#363); `TZMF120` was not `LIST`-checked on any stand before release. 1.1.0 released 2026-09-14 under `TZMF110`, the first level (free on mvsdev, `JOB00360`, CDS and ACDS). `TZMF111` (1.1.1, never cut -- the libc370 2.0 port made the next release 1.2.0) is unspent and unassigned. 1.0.0 and 1.0.1 shipped with no `[distribution]`, so nothing below `TZMF110` was ever assigned |
| rexx370 1.0.0 | `TRXX100` | — | proposed (first level) |
| brexx370 (BREXX/370) 3.0.0 | `TBRX300` | — | proposed (first level). The prefix `TBRX` is BREXX/370's; the digits follow the release version, which is still open (`PARSE VERSION` shows `3.0.0-dev`, JCC builds showed `V2R5M3`). Not yet checked on any stand |
| nsf370 0.1.0 | `TNSF010` | — | proposed (first level) |
| oftpd 0.2.0 | `TOFT020` | `TOFT010` | the first final release; free on m38l (`JOB01801`), m38x (`JOB00654`), m38b (`JOB02734`) and m38r (`JOB00923`), CDS and ACDS, RC 04 with no DELBY (2026-10-19). 0.1.0-dev was released as a prerelease 2026-10-13 under `TOFT010` and installed the same day on m38l, m38x, m38b and m38r (see the burned list) |

**Burned, do not reuse:** `TUFS110` (ufsd 1.1.x — never released, but applied
and accepted on a test system), `TUFS120` (ufsd 1.2.0–1.2.2, `REC APP ACC` on
mvsdev), `TUFS130` (ufsd 1.3.0, released 2026-09-14), `TUFS140` (ufsd 1.4.0, released 2026-10-13), `TFTP100` (ftpd 1.0.x,
released), `TFTP110` (ftpd 1.1.0, released 2026-09-14), `TFTP120` (ftpd 1.2.0, released 2026-10-13), `THTP400` (httpd 4.0.x,
`REC APP ACC` on mvsdev), `THTP410` (httpd 4.1.0, released 2026-09-14), `THTP420` (httpd 4.2.0, released 2026-10-13), `THTP430` (httpd 4.3.0, released 2026-10-15),
`TZMF110` (mvsMF 1.1.0, released 2026-09-14), `TZMF120` (mvsMF 1.2.0, released 2026-10-13), `TZMF130` (mvsMF 1.3.0, released 2026-10-15), `TOFT010` (oftpd 0.1.0-dev,
prerelease 2026-10-13, `REC APP ACC` on m38l `JOB01692`, m38x `JOB00608`,
m38b `JOB00728`, m38r `JOB00381`; free before on m38r `JOB00358`, m38b
`JOB00579`, m38l `JOB01671`, m38x `JOB00592`), `TXPR100` (inline-delivery experiment, received and rejected
on `mvsdev`), `TTST001`–`TTST007` (the `++VER DELETE` measurement and
the `REQ` semantics probe, both 2026-09-14) and `TTST008`–`TTST010` (the alias
measurement on mvsdev, 2026-09-27, mvslovers/mbt#112; afterwards removed from
both zones by UCLIN, `ALTCLN JOB00520` — spent all the same), and `TSMP100`
with its PTF `USMP001` (the smptest prototype, applied on mvsdev 2026-08-08,
KB `ECO-0007`).

**Never `TMVS…`** — MVS/CE carries applied USERMODs called `TMVS804`,
`TMVS816` and `TMVS817`; the same holds for `TIST801`, `TJES801`, `TNIP800`
and `TTSO801`. Four of the seven are applied on TK5 as well (`TMVS816`,
`TMVS817`, `TJES801`, `TNIP800`); `TMVS804`, `TIST801` and `TTSO801` are on
MVS/CE only. Those three make the collision **distribution-specific**: you
would find it on one system and miss it on the other. (SMP CDS of MVSCE-LAB and
MVSTK5-BLD, MVSHIST extractions 2026-09-22/23. Corrected 2026-10-11: this
paragraph used to say TK5 carries none of the seven.)

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
stand is not enough — the `TMVS804`/`TIST801`/`TTSO801` collisions above are
applied on MVS/CE and absent on TK5, so a single check finds them on one system
and misses them on the other. And coverage that is inferred from a neighbouring
row goes wrong in both directions: a row that silently covers one stand where
the row above covered two reads as equally thorough (ftpd, 2026-09-14), and a
stale "one stand only" note understates coverage and holds back a release that
was ready (httpd, same day). Neither was written untruthfully; both are
invisible without job numbers.

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

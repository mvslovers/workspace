# mvslovers Project Ecosystem — Root Context

Shared context for every project in the mvslovers ecosystem. Each project has
its own `CLAUDE.md`, which extends this one. Keep this file short: detail that
only some tasks need lives in `~/repos/mvs/.workspace/context/` and is read
when the task calls for it (see **Read when relevant**).

All projects target **MVS 3.8j on Hercules**, written in **C99 (gnu99)** and/or
**S/370 assembler**, cross-built on macOS/Linux with the **cc370** toolchain.

## Projects

```
cc370      GCC 3.4.6 fork: cc370, as370, ar370, ld370
libc370    C library + MVS extras; installed into the host sysroot (-lc)
ufsd       Unix-like virtual filesystem server
ufsd-utils ufsd tooling
ftpd       FTP server                                needs: ufsd
httpd      HTTP server                               needs: ufsd, crypto370
mvsmf      z/OSMF REST API clone (httpd module)      needs: ufsd, httpd, crypto370
httplua    Lua CGI handler (httpd module)            needs: ufsd, httpd, lua370
httprexx   REXX Server Pages (httpd module)          needs: ufsd, httpd
rexx370    REKS/370: REXX interpreter, TSO/E V2      needs: lstring370
lua370     Lua 5.4: LUA/LUAC + liblua370.a
lstring370 reentrant length-prefixed strings (consumers inject alloc/dealloc)
crypto370  SHA-256, Blowfish, base64 (moved out of libc370 2.0)
zlib370    zlib 1.3.1 (released, adoption under evaluation)
oftpd      OFTP server + utilities (not yet released)
mbt        MVS Build Tools
brexx370   BREXX/370 -- maintenance mode, see below
```

- **httprexx does not build against rexx370**: it resolves `IRXINIT`/`IRXEXEC`/
  `IRXTERM` at runtime and vendors only headers. rexx370 is a runtime
  prerequisite, never a `[dependencies]` entry.
- **cc370 and libc370 versions go together** (libc370 2.1.x needs cc370
  `>= 1.1.0, < 2`). Before releasing either, read its `internals/releasing.md`.
- **brexx370 gets no new features**: only the mbt/cc370 build, one cleanup
  pass and the TSO integration (`ZMG0001`). New REXX function goes into
  rexx370. Anything else in brexx370 is the maintainer's call.
- Legacy, no further work: c2asm370, crent370, ufs370, ufs370-tools, ftp370,
  mqtt370 (+broker, +cli).

Status, dates and history per project: `~/repos/mvs/.workspace/context/status.md`.

### Product names

A product has a **name** for people and a **repo name** for machines.

| Product name | Repo |
|---|---|
| CC/370, LIBC/370, MBT, BREXX/370, LUA/370 | cc370, libc370, mbt, brexx370, lua370 |
| UFSD, FTPD, HTTPD (modules HTTPLUA, HTTPREXX), mvsMF, OFTPD | ufsd, ftpd, httpd, mvsmf, oftpd |
| REKS/370 (never "REXX/370", that is IBM's) | rexx370, to be renamed reks370 |
| lstring370, crypto370 | the same |

The rexx370 repository is to be renamed reks370. Until the rename has
happened, commands, paths and dependencies keep `rexx370`.

The product name goes into prose, titles, books, web and release pages, README
headings. The repo name stays in everything a machine reads: commands, paths,
file and data set names, config, URLs. First mention per document: both, as
"CC/370 (cc370)". A `CHANGELOG.md` keeps the names it was written with.

## Target platform constraints

These are hard limits of the target. Do not work around them.

- **Memory is the #1 constraint.** Prefer stack over heap where safe, free
  every allocation, avoid large static buffers and needless string copies.
- **24-bit addressing** only; nothing may assume addresses above 16 MB.
- **C99 (gnu99)** with cc370; no C11, no VLAs; `-Wall -Werror`, fix warnings
  rather than suppress them.
- **EBCDIC (CP037)** at runtime: use character literals, never ASCII codes;
  no ASCII collating assumptions.
- **No POSIX**: no `fork`/`exec`, `pthread`, `mmap`, `sigaction`, `dlopen`;
  no Unix paths in MVS code.
- **Static linking**: ld370 resolves by autocall from `.a` archives.
- **Limited stack**: no deep recursion; state the depth where recursion is
  unavoidable.
- **as370 is not HLASM** (no `OPSYN` etc.); assembled modules are RENT and REUS.

## Build (mbt)

Almost every project is on **mbt 3**: the `mbt` program, `mbt.toml`, no
submodule, no Makefile (`mbt --help` lists the commands; mbt `docs/MIGRATION.md`
explains the model). rexx370 is still on mbt 2 (`project.toml`, `make …`).
cc370 and libc370 build with plain `make`.

```
mbt build [--all] [--tests]     mbt test            host tests
mbt test --mvs [--target NAME]  mbt check           host, then MVS
mbt deploy [--target NAME]      mbt package / dist  release artifacts, SMP package
mbt doctor                      mbt target list | ping NAME [--tso]
```

- **MVS systems come from `~/.mbt/targets.toml`, not `.env`.** Without
  `--target` or `MBT_TARGET`, mbt uses the default target. Name the target
  explicitly for anything that writes, and check it with `mbt doctor`.
- Tests use `mbtcheck.h`; the return code is the contract (0 = passed).
- Dependencies are `owner/repo` with a semver range; `mbt.lock` is committed.
  Every new dependency is permanent: prefer libc370 or in-repo code, and give
  the reason in the PR.

### Libraries on MVS

`<PROD>.LINKLIB` belongs to SMP; only the install job writes it. Development
builds deploy to `<PROD>.DEV.LINKLIB` (mbt 3's default), which comes **first**
in the STEPLIB and needs its own APF entry. A DEV library has no business on a
production system. Details, APF and rename traps: `~/repos/mvs/.workspace/context/deploy.md`.

## Read when relevant

Read these files **before** the task they cover, not by default:

| Before you … | read |
|---|---|
| cut a release, edit `[distribution]`/`[smp]`, pick an FMID, run any SMP job | `~/repos/mvs/.workspace/context/smp.md` |
| deploy to a stand, change a STEPLIB, APF or library names | `~/repos/mvs/.workspace/context/deploy.md` |
| let a product take an SVC slot | `~/repos/mvs/.workspace/context/svc.md` |
| write or move documentation, start a book | `~/repos/mvs/.workspace/context/books.md` |
| debug a running HTTPD or one of its modules | `~/repos/mvs/.workspace/context/httpd-debug.md` |
| need a project's history or status | `~/repos/mvs/.workspace/context/status.md` |
| answer an MVS-internals question | `~/repos/mvs/knowledge/INDEX.md`, then its retrieval ladder |

The short SMP rules everyone needs:

- One FMID per **minor** release: `T` + three product letters + major + minor
  + `0` (`TUFS130`). Each id is spent once, never reused; the burned list is in
  `smp.md`. No version component may exceed 9.
- Never `E…` (IBM's namespace on MVS 3.8j), never `TMVS…`. Usermods to IBM
  modules use `ZMG…`.
- **A return code says the job ran, not that the work happened.** Verify an
  install by listing the target library members and the `LIST` stanza.
- A version floor on another product goes into the installation guide as
  prose; `REQ` is conjunctive and means "exactly this level".

## Knowledge base

`~/repos/mvs/knowledge` is the shared, persistent memory of the ecosystem, with
its own rules in `knowledge/CLAUDE.md`. For MVS internals, answer from the KB
or say it does not cover it.

**When a session establishes an important finding backed by a measurement**
(a job, a dump, a test result) that holds beyond the task at hand, **ask the
maintainer whether it should go into the KB.** On a yes, write it to
`knowledge/inbox/` (date in the file name, any language, source and job numbers
included); the KB's ingest turns it into a document. Do not write KB documents
outside `inbox/` unless asked. After a long debugging session with real
insight, offer a postmortem the same way.

## Working autonomously

The line is **reversibility**, not the kind of action. The harness's permission
mode applies on top of this; this section says where asking adds nothing.

**Go ahead without asking:**

- read anything, run builds and host tests, `mbt doctor`, `mbt target ping`
- create and edit files in a project, create a feature branch
- when asked to implement something: commits on the feature branch, opening
  the issue and the PR for that work — the request covers them
- fix what the change needs, also in code the user did not name, as long as it
  serves the task (say so in the summary)
- everything inside **your own throwaway container** (below)

**Ask first:**

- push to or merge into `main`, merging a PR, tags, releases
- any write to a real stand: dev1, m38b, m38l, m38r, m38x, mvsdev's own MVS
  (deploy, submit, allocate, delete, PARMLIB/PROCLIB, APF, P/S of STCs).
  **One exception:** an nsf370 session may run its own cycle on dev1 without
  asking — `P NSFS`/`P NSFV`, `mbt deploy --target dev1`, `S NSFS`/`S NSFV`,
  and `mbt test --mvs --target dev1`. Everything else on dev1 still asks.
- writes to `SYS1.*` data sets: an approval covers one task only and does not
  carry over to the next, even on the same stand
- deleting data git cannot restore (untracked files, measurement results)
- writing to the KB (see above)
- a change that grows well beyond the task (a refactor, a second feature)

### Throwaway containers

A session that started its own container with `mvsce-target up`
(`~/repos/mvs/mvs-docker/mvsce/`, MVS/CE by default, TK5 with `--dist tk5`) may
do anything to MVS inside it without asking.

- Only your own container; one started by another session is not yours.
- Check that `--target env` / `MBT_TARGET_*` points at the container's port
  before a write — a stale variable aims at whatever it last named.
- Always `down` at the end and confirm with `list`, also after a failure;
  `reap` cleans up after a crashed session.
- A container result is not a stand result: `mvsce` has the products copied
  in, `tk5` has them SMP-installed from releases; neither has a stand's
  history (old FMIDs, tombstones, APF entries).
- Short tests on mvsdev (`--host mvsdev`, cap of three); load, soak and
  many-job runs locally (no `--host`), because they slow the stands.

```sh
eval "$(~/repos/mvs/mvs-docker/mvsce/mvsce-target up --host mvsdev)"    # --dist tk5 for TK5
mbt target ping env --tso --wait 60      # mvsMF up is not TSO up
mbt test --mvs --target env
~/repos/mvs/mvs-docker/mvsce/mvsce-target down "$MVSCE_TARGET_NAME" --host mvsdev
~/repos/mvs/mvs-docker/mvsce/mvsce-target list --host mvsdev
```

## Git and release texts

- Non-trivial work: issue + feature branch + PR referencing the issue.
- Commit messages in clear English, saying what and why.
- **Never mention AI, Claude or any AI tool** in commits, code, docs, PRs or
  release texts.
- After a commit, push or merge: update the project's `TODO.md` if it has one
  — strike what landed, drop what became obsolete.
- `CHANGELOG.md` and release pages are for someone who has never heard of this
  ecosystem: no consumer project names, no job numbers, no names of private
  systems. Rework each release page before it is announced: lead paragraph,
  "Read this first", before/now table of fixes, install, full changelog.
- `docs/` is for users, `internals/` for maintainers; no `doc/`
  (`~/repos/mvs/.workspace/context/books.md`).

## Discipline

- **Verify before fixing**: first a test that reproduces the failure, then the
  fix, then the test passes. Read the whole dump or error output first; change
  one variable at a time.
- **Re-derive a claim from the artefact, not from memory.** The number gets
  checked; the sentence written next to it usually does not. Open the file,
  grep the source, run the filter before you state it.
- **Tools fail by answering.** Exit 0 and a plausible number is the failure
  mode, so check a count against a known answer before building on it.
  - Write flags inline, never via a shell variable: zsh does not split `$VAR`
    (`as370 $MACFLAGS` got one giant `-I`, exited 0, wrote a wrong deck;
    `curl $A` sent a broken userid and 401'd like a server fault).
  - Prefer `find`, `git ls-files` or a glob over `ls` in pipelines (`ls` is
    aliased to a long lister here).
- **Check every MVS return code**; no silent error handling. Say "I'm not
  sure X handles Y" instead of guessing.
- Two tools disagreeing is not yet a cause, and two statistics of one dataset
  pointing opposite ways is not a contradiction — usually a few large members
  carry the aggregate.

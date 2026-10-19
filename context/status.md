# Project status and history

Per-project notes and the status table, moved verbatim from the root CLAUDE.md on 2026-10-19.
Dates and PR numbers here age; the repo itself (and its TODO.md) is the current source.

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
zlib370  — zlib 1.3.1 (static library)                  needs: — (sysroot libc only)
oftpd    — OFTP file transfer server + utilities        needs: — (sysroot libc only)
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

**zlib370 is released, its adoption under evaluation** (maintainer,
2026-10-12). It was legacy until it moved to mbt 3 and libc370 2.x
(zlib370#2); 1.0.0 was released on 2026-10-13, the first final release cut
with `mbt release` and `release3.yml`. Whether it stays
depends on the deflate storage per stream measured on dev1: 268 KB at the
default (windowBits 15, memLevel 8), 71 KB at 13/6, 30 KB at 12/4. A likely
consumer is HTTPD's `Content-Encoding: gzip`, which needs deflate only.
zlib only: the minizip code it carried was removed (maintainer, 2026-10-12);
MVS MINIZIP/MINIUNZ live in MVS-sysgen/minizip and ship with TK5.

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
moving the build from JCC to mbt / cc370 + libc370 (on mbt 3 since
brexx370#421), one cleanup pass, and
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
| zlib370 | mbt 3 | v1.0.0 released 2026-10-13, adoption under evaluation; on mbt 3 and libc370 2.x since 2026-10-12 (zlib370#2), CI green; zlib only (minizip removed) |
| rexx370 | mbt v2 | building; no CI workflow yet |
| brexx370 | mbt 3 | on mbt 3 since 2026-10-11 (brexx370#421; mbt.toml, no submodule, `legacy/` gone), 164 of 164 outputs byte-identical to mbt 2; maintenance mode; REXX suite 183/183 on MVS/CE (batch and TSO steps) |
| oftpd | mbt 3 | new 2026-10-12 (as oftp370, renamed 2026-10-13); `mvslovers/oftpd`, CI green; prerelease 0.1.0-dev released 2026-10-13 (v0.1.0-dev, 1ca9786), SMP-installed on m38l, m38x, m38b, m38r; first final release 0.2.0 (`TOFT020`, deletes `TOFT010`) |
| mbt | — | active |

### Legacy / not maintained

No further work. Superseded: **c2asm370** → cc370, **crent370** → libc370.
Also unmaintained: ufs370, ufs370-tools, ftp370, mqtt370 (+broker,
+cli).


# mbt 2 reference (rexx370 only)

Moved verbatim from the root CLAUDE.md on 2026-10-19; every other project is on mbt 3.

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

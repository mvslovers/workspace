# Deploy libraries, APF and the .env configuration

Read before deploying to a stand, touching a STEPLIB or IEAAPF00. Moved verbatim from the root
CLAUDE.md on 2026-10-19.

**Note for mbt 3:** `mbt deploy` replaces members and never deletes the library (`mbt --help`),
and MVS systems come from `~/.mbt/targets.toml`, not `.env` (mbt `docs/MIGRATION.md` §5). The
paragraphs below on DELETE-before-RECEIVE and on `.env` describe mbt 2.

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

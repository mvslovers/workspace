# Live debugging via HTTPD display modules

For httpd, mvsmf, httprexx, httplua. Moved verbatim from the root CLAUDE.md on 2026-10-19.

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
the next module load failed `IEA703I 106-0F` — read then as insufficient
*contiguous* storage (but see below: `0F` itself does not say storage) —
killing every CGI on that HTTPD until `P HTTPD` / `S HTTPD`. Two
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
abend code sits in the `IEA703I` line next to it, and `106` is a fetch
failure, not a missing member. Check that before hunting a member that is
present (mvslovers/httpd#210).

**`106-0F` does not mean storage.** IBM's text for return code `0F`: "an
uncorrectable I/O error occurred, or an error in the load module caused the
channel program to fail"; storage is `0C`. On m38b on 2026-10-15 HTTPD hit
`106-0F` fetching MVSMF with 7.27 MB free in one block, and so did PL/I
compiler phases on other volumes (mvslovers/httpd#300). So read `fn=storage`
before calling a `106-0F` a shortage. A failed fetch also costs storage: the
module's size, for good (82 pages for MVSMF, httpd#300).

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

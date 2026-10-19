# Manuals: docs/ vs internals/, book numbers, how books ship

Read before writing or moving documentation or starting a book. Moved verbatim from the root
CLAUDE.md on 2026-10-19.

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
| ML02 | MBT (v3 only) | 0001 User's Guide, 0002 Reference -- on `main` (mbt#213), Draft |
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
(decided 2026-10-07; libc370 will get one). brexx370 no longer needs
the rule: its Sphinx site is gone (brexx370#417) and Read the Docs builds
from the books (brexx370#396), the single-source route named below.
A change to documented behaviour updates the book *and* the Sphinx
source in the same PR, and the cross-reader checks both against each other
as well as against the code. This is double maintenance and a drift risk
by construction, so it stands only until one source can feed both; the
candidate is Typst's HTML export from the book sources (experimental in
typst 0.15), published to Read the Docs through a custom build.

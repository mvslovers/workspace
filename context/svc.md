# Installation SVC numbers — the registry

Read before a product takes an SVC slot. Moved verbatim from the root CLAUDE.md on 2026-10-19.

### Installation SVC numbers — one per product, registered here

A product that installs an SVC of its own at runtime (an STC that takes
over an unused SVC table slot, so unauthorized callers can reach it)
**takes a number from this table and nowhere else**. Two products that
each pick "a free one" at start take the same slot on the same stand.
An STC checks at start that its slot still holds the invalid-SVC entry
point and refuses to take it otherwise; it gives the slot back at stop
and in its ESTAE.

"Free" means the entry point equals the invalid-SVC routine's, the one
most of 200-255 share (`00CCC8` on MVS/CE, `017068` on TK5) -- **not
zero**. Measured read-only on 2026-10-14 (oftpd `internals/xmem.md`
section 3, with job numbers): free on dev1, m38l, m38x, m38b and m38r
alike are **200-219, 230 and 235-239**; MVS/CE uses 240-255, TK5 uses
220-229, 231-234, 241-244 and 248. 244 is the authorization SVC the
STCs use; MVS 3.8j has no `IEASVCxx`, so nothing else appears at IPL.

| SVC | Product | State |
|---|---|---|
| 237 | oftpd (OFTPD) | assigned 2026-10-14 (oftpd#1). **Taken and given back on m38x on 2026-10-18**, twice -- once through the ESTAE after an abend, once through the clean stop (install `JOB00637`/`JOB00641`, read back `JOB00638`/`JOB00642`, every reading taken independently with a BREXX `STORAGE()` job; oftpd `internals/xmem.md` section 10). The stand was reset afterwards and holds no entry. **Nothing is installed anywhere today**: the transport is not active yet, and `SVC=` has no default, so an OFTPD whose `OFTPPRM0` omits it installs nothing and says `OFTP038I` |
| 239 | nsf370 (NSFV/NSFS) | taken by its STC on MVS/CE (nsf370 ADR-0038, 2026-07-21); not measured on TK5 |

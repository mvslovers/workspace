Resolve GitHub issue #$ARGUMENTS end-to-end in the current repository.

## Preparation

1. **Detect context:**
   Run: `REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)` to get the current repo (e.g. `mvslovers/mvsmf`).
   Run: `PROJECT=$(basename $(pwd))` to get the project name.

2. **Read the issue:**
   Run: `gh issue view $ARGUMENTS`

3. **Read project guidance:**
   - If a `CLAUDE.md` exists in the repo root, read it.
   - If the issue references a spec document (e.g. `doc/uss-spec.md` or similar), read that too.
   - If the issue has a label that maps to a spec (check CLAUDE.md for label→spec mappings), read the spec.

4. **Create a feature branch:**
   Run: `git checkout main && git pull && git checkout -b issue-$ARGUMENTS-<short-description>`
   Use a short kebab-case description derived from the issue title.

## Notion Integration

5. **Find and update Notion task to "In Progress":**
   Search the Issues & Tasks data source (`data_source_url: "collection://c666f502-1973-4f96-bb83-3c743d1d2b30"`)
   with query `"https://github.com/$REPO/issues/$ARGUMENTS"` (the full GitHub issue URL).
   This matches the `GitHub URL` property which is the most reliable identifier.
   If no result, fall back to searching for `"#$ARGUMENTS $PROJECT"`.
   Verify the match: the `GitHub URL` property must end with `/$REPO/issues/$ARGUMENTS`.
   If a matching page is found, update its `Status` property to `"In Progress"`.
   If not found, that's fine — not all issues are tracked in Notion.

## Implementation

6. **Analyze:**
   Read the issue body carefully. Identify all affected files. Study existing patterns in nearby code — especially in the same source file or similar modules.

7. **Implement:**
   Write code following the conventions in CLAUDE.md. Pay attention to:
   - Language standard (C89 vs gnu99 — check project CLAUDE.md)
   - Platform constraints (24-bit addressing, EBCDIC, no POSIX)
   - Naming conventions (asm labels, function prefixes)
   - Never reference AI or Claude in code, comments, or commit messages

8. **Verify:**
   - If a Makefile exists: run `make compiledb` and check clangd diagnostics
   - If tests exist for the affected area: verify they still pass or update them
   - No errors in changed files

9. **Update tests:**
   If the change affects functionality with existing tests, update them.
   If adding new functionality, add matching tests following the project's test patterns.

10. **Update docs:**
    If the change affects a documented API or interface, update the corresponding docs.

## Finalize

11. **Commit:**
    Write a descriptive commit message. Reference the issue: `Fixes #$ARGUMENTS`
    Never mention AI, Claude, or automation in the message.

12. **Push and create PR:**
    Run: `git push -u origin HEAD`
    Run: `gh pr create --title "<descriptive title>" --body "Fixes #$ARGUMENTS"`

13. **Update Notion status to "In Review":**
    Use the same Notion page found in step 5 (no new search needed).
    Update its `Status` property to `"In Review"`.

14. **Report:**
    Summarize what was done, which files changed, and what needs manual verification.

If any step fails or is ambiguous, stop and ask rather than guessing.

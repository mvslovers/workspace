Close a GitHub issue and update Notion. Usage: /close-issue <number>

## Steps

1. **Read the issue:**
   Run: `gh issue view $ARGUMENTS`

2. **Check for linked PR:**
   Run: `gh pr list --search "Fixes #$ARGUMENTS OR Closes #$ARGUMENTS"`
   If a merged PR exists, reference it in the closing comment.

3. **Close on GitHub:**
   Run: `gh issue close $ARGUMENTS --comment "Resolved in PR #<pr-number>."` (if PR exists)
   Run: `gh issue close $ARGUMENTS --comment "Resolved."` (if no PR)

4. **Update Notion status to "Done":**
   Detect the repo: `REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)`
   Search the Issues & Tasks data source (`data_source_url: "collection://c666f502-1973-4f96-bb83-3c743d1d2b30"`)
   with query `"https://github.com/$REPO/issues/$ARGUMENTS"` (the full GitHub issue URL).
   This matches the `GitHub URL` property which is the most reliable identifier.
   If no result, fall back to searching for `"#$ARGUMENTS"`.
   Verify the match: the `GitHub URL` property must end with `/$REPO/issues/$ARGUMENTS`.
   If a matching page is found, update its `Status` property to `"Done"`.

5. **Report:** Confirm closure on both GitHub and Notion.

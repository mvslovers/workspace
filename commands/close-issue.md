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
   Search Notion Issues & Tasks for "#$ARGUMENTS —".
   If found, update its Status property to "Done".

5. **Report:** Confirm closure on both GitHub and Notion.

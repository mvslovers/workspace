Show the current status of the project — open issues, PRs, and Notion tasks.

## Steps

1. **Detect context:**
   Run: `REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)`
   Run: `PROJECT=$(basename $(pwd))`

2. **GitHub status:**
   Run: `gh issue list --state open --limit 20`
   Run: `gh pr list --state open`
   Summarize: number of open issues, open PRs, any issues labeled as blocked.

3. **Notion status:**
   Search the Issues & Tasks data source (`data_source_url: "collection://c666f502-1973-4f96-bb83-3c743d1d2b30"`)
   for the project name (e.g. `"mvsmf"`, `"crent370"`).
   From the results, group by `Status` (To Do, In Progress, In Review, Blocked).
   Report counts per status.

4. **Recent activity:**
   Run: `git log --oneline -10` to show recent commits.
   Highlight any that reference issue numbers.

5. **Present a compact summary:**
   ```
   Project: <name> (<repo>)
   
   GitHub:  X open issues, Y open PRs
   Notion:  A To Do, B In Progress, C In Review, D Blocked
   
   Recent commits:
     <last 5 commits>
   
   Open PRs:
     #N — <title> (by <author>)
   
   Blocked issues:
     #N — <title> (reason: ...)
   ```

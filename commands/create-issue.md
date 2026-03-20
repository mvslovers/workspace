### /create-issue \<TASK-NN | description\>

Create a GitHub issue, either from a Notion task or from a manual description.

**Mode 1 — From Notion task (argument is TASK-NN or a number):**

1. **Determine the repo** — `git remote get-url origin` → extract `owner/repo`
2. **Find the Notion task** — Search the MVSLOVERS "Issues & Tasks" database
   (data source `collection://c666f502-1973-4f96-bb83-3c743d1d2b30`) for the
   task matching `Task ID` = NN.
3. **Read the task** — Fetch the Notion page. Extract:
   - `Title` → GitHub issue title
   - `Description` → first line of the GitHub issue body (summary)
   - Page content → remainder of the GitHub issue body (full details)
   - `Priority` → GitHub label (if labels exist on the repo)
   - `Type` → GitHub label (Bug, Feature, Enhancement, Chore)
4. **Verify project match** — Resolve the task's `Project` relation.
   Fetch the linked project page and check that its `Repo URL` matches
   the current git remote. If not, warn and ask for confirmation.
5. **Create the GitHub issue:**
   ```bash
   gh issue create --repo <owner/repo> --title "<title>" --body "<body>"
   ```
6. **Write back to Notion** — Update the Notion task's `GitHub URL` property
   with the URL returned by `gh issue create`.
7. **Report** — Print the GitHub issue URL and the Notion task link.

**Mode 2 — Manual (argument is free text):**

1. **Determine the repo** — `git remote get-url origin` → extract `owner/repo`
2. **Create the GitHub issue** using the argument as the title.
   Ask for a body if the user hasn't provided enough context.
   ```bash
   gh issue create --repo <owner/repo> --title "<description>" --body "<body>"
   ```
3. **Report** — Print the GitHub issue URL.

**Argument detection:**
- If the argument matches `TASK-\d+` or is a plain integer → Mode 1 (Notion)
- Otherwise → Mode 2 (manual)

**Error handling:**
- Task not found in Notion → stop, report "TASK-NN not found"
- Project mismatch (Notion task belongs to a different repo) → warn, ask
- `gh` not authenticated → stop, report "run gh auth login"
- Notion task already has a `GitHub URL` → warn "issue already exists at <url>", ask before creating a duplicate

**Example usage:**
```
/create-issue TASK-15
/create-issue 15
/create-issue Fix the dataset list pagination bug
```

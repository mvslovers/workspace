Create a new GitHub issue in the current repository. Usage: /create-issue <title>

The argument is the issue title. You will interactively gather the remaining details.

## Steps

1. **Detect context:**
   Run: `REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)`
   Run: `PROJECT=$(basename $(pwd))`

2. **Read project guidance:**
   If a `CLAUDE.md` exists, read it to understand the project's conventions, labels, and milestones.

3. **Gather details by asking the user:**
   - What type of issue is this? (Bug, Feature, Enhancement, Chore, Research)
   - Brief description of the problem or desired behavior
   - Any specific files or components affected?
   - Priority? (Critical, High, Medium, Low)
   - Should this be assigned to a milestone?

4. **Draft the issue body** with these sections:
   ```
   ## Summary
   <concise description>

   ## Affected Files
   <list of files/modules, if known>

   ## Implementation Notes
   <technical approach, constraints, patterns to follow>

   ## Testing
   <how to verify the fix/feature>

   ## Blocked by / Blocks
   <dependencies on other issues, if any>
   ```

5. **Show the draft** to the user for review before creating.

6. **Create on GitHub:**
   Run: `gh issue create --title "<title>" --body "<body>" --label "<labels>"`

7. **Create in Notion (optional):**
   Search Notion Projects database for the current project name.
   If found, create a matching entry in the Issues & Tasks database:
   - Title: `#<number> — <title>`
   - Project: link to the found project
   - Type: matching the issue type
   - Status: "To Do"
   - Priority: as discussed
   Report the Notion page URL.

8. **Report:** Show the GitHub issue URL and Notion URL (if created).

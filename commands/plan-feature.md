Plan a new feature with spec, issues, and Notion tracking. Usage: /plan-feature <feature-name>

This is the "Opus planning" workflow — analysis and spec first, implementation issues second.

## Steps

1. **Detect context:**
   Run: `REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)`
   Run: `PROJECT=$(basename $(pwd))`
   Read `CLAUDE.md` for project conventions.

2. **Gather requirements by asking the user:**
   - What should this feature do?
   - Are there external API specs to follow? (links to docs)
   - What existing code is affected?
   - Are there dependencies on other libraries or projects?
   - What's the scope / priority?

3. **Analyze the codebase:**
   Review the relevant source files, existing patterns, and architecture.
   Identify gaps, constraints, and integration points.

4. **Draft a specification** covering:
   - Executive Summary
   - Current state / existing functionality
   - Gap analysis (what's needed vs what exists)
   - Architecture / design decisions
   - Endpoint or API specifications (if applicable)
   - Error handling strategy
   - Implementation plan with task breakdown and dependencies
   - Testing strategy
   - Open questions

5. **Review with the user:**
   Present the spec, discuss open questions, iterate until approved.

6. **Save the spec:**
   Write to `doc/<feature-name>-spec.md` in the repo.

7. **Create Notion concept:**
   Add an entry in the Concepts database:
   - Title: `<Project> <Feature> — Specification`
   - Category: as appropriate (API Design, Architecture, etc.)
   - Status: "Approved" (after user approval)
   - Project: link to current project

8. **Create GitHub issues:**
   Break the implementation plan into individual issues, each with:
   - Clear title, description, acceptance criteria
   - Labels (feature label, phase label)
   - Dependency references (Blocked by / Blocks)
   Create via: `gh issue create --title "..." --body "..." --label "..."`

9. **Create Notion issue entries:**
   For each GitHub issue, create a matching entry in the Issues & Tasks data source
   (`data_source_id: "c666f502-1973-4f96-bb83-3c743d1d2b30"`):
   - `Title`: `#<number> — <title>`
   - `Project`: link to project (resolve via `collection://e0e18b50-53e1-404d-937b-9096ed63671e`)
   - `GitHub URL`: the GitHub issue URL
   - `Type`, `Priority`, `Effort` as appropriate
   - `Status`: `"To Do"`

10. **Report:**
    Summary of what was created:
    - Spec file location
    - Notion concept URL
    - List of GitHub issues with numbers
    - Suggested implementation order

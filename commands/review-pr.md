Review an open Pull Request. Usage: /review-pr <number>

## Steps

1. **Fetch the PR:**
   Run: `gh pr view $ARGUMENTS`
   Run: `gh pr diff $ARGUMENTS`

2. **Read project guidance:**
   If a `CLAUDE.md` exists, read it for coding conventions, platform constraints, and testing requirements.

3. **Analyze the diff** for:
   - **Correctness**: Does the code do what the linked issue asks for?
   - **Platform compliance**: 24-bit addressing, EBCDIC, memory management, no POSIX, correct C standard
   - **Patterns**: Does it follow established patterns in the codebase? (Check nearby existing code)
   - **Error handling**: Are all error paths covered? Memory leaks? Missing cleanup?
   - **Edge cases**: Buffer overflows, NULL dereferences, integer overflow
   - **Tests**: Are new/changed features covered by tests?
   - **Docs**: Are docs updated if behavior changed?

4. **Check for common MVS pitfalls:**
   - Hardcoded ASCII values (must use character literals)
   - Stack-heavy code (deep recursion, large local arrays)
   - Missing `asm()` labels on new public functions
   - VLAs (forbidden)
   - Multi-byte `recv()` (forbidden — TCP/IP ring buffer bug)

5. **Report findings** as a structured review:
   - **Approve / Request Changes / Comment**
   - List specific issues with file:line references
   - Suggest fixes for each issue
   - Note anything that looks good or well-done

6. **Optionally post review:**
   Ask if the user wants to post the review as a GitHub comment:
   Run: `gh pr review $ARGUMENTS --comment --body "<review>"`

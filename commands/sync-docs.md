Synchronize endpoint/API documentation with the current implementation.

## Steps

1. **Detect project type:**
   Check which source files exist to determine what kind of docs to sync:
   - `src/mvsmf.c` with `add_route()` → REST endpoint docs in `doc/endpoints/`
   - `src/*.c` with handler functions → module documentation
   - Other patterns as applicable

2. **Scan implementation:**
   For REST APIs: extract all route registrations (method, URL pattern, handler function).
   For libraries: extract all public function declarations from headers.

3. **Scan documentation:**
   List all documentation files in `doc/` (or the project's doc directory).

4. **Compare and report:**
   - **Missing docs** — implemented features with no documentation
   - **Orphaned docs** — documentation for features that no longer exist
   - **Potentially outdated** — docs whose corresponding source was modified more recently

5. **Generate stubs:**
   For any missing documentation, create stub files following the project's existing doc format.
   If no format exists yet, use a sensible default:
   ```
   # <Endpoint/Function Name>
   ## Description
   TODO
   ## Request / Parameters
   TODO
   ## Response / Return Value
   TODO
   ## Examples
   TODO
   ```

6. **Report:** Summarize findings — how many items documented, missing, orphaned, stubs generated.

---
description: Review the current Codex changes, remove Codex-added comments, verify behavior, and report the handoff.
argument-hint: [optional review focus]
---

# Goal

Continue from the current dirty working tree. Codex modified the People, Add Person, Add Role, and Upload Timesheet flows. Inspect the actual diff before editing because unrelated user changes may also be present.

# Codex change summary

1. Add Person now loads Organization, Branch, Job Level, Skill, and Staffing Role independently, keeps newly created roles available, and uses downward-opening dropdowns.
2. Add Role and Add Person show success states before closing.
3. Upload Timesheet accepts drag and drop as well as file browsing.
4. Talenta XLSX headers such as `Employee ID*` and `Date*` are normalized correctly.
5. A successful timesheet upload shows a success modal and navigates the People page to the imported date range.
6. The timesheet API returns the imported date range and the number of created employees.
7. Unknown Talenta Employee IDs now create active People records from Full Name and Employee ID. Existing employees are reused by external ID, and matching Organization, Branch, Job Position, and Job Level master records are attached when available.
8. Talenta numeric `Time Off Halfday` values `0`, `1`, and `2` are supported.
9. The frontend accepts both the new API response and an older response that omits `createdEmployees`, defaulting that value to zero.
10. Regression coverage uses `docs2/contoh_data/Attendance Mei_Talenta.xlsx` and expects 1,023 imported rows and 33 People rows.

Primary touched areas:

- `apps/web/src/components/add-person-drawer.tsx`
- `apps/web/src/components/add-role-dialog.tsx`
- `apps/web/src/components/capacity-upload-timesheet-dialog.tsx`
- `apps/web/src/components/people-capacity-page.tsx`
- `apps/web/src/lib/schemas.ts`
- `packages/design-system/src/components/ui/select.tsx`
- `services/api/internal/capacity/`
- `services/api/internal/httpapi/capacity.go`
- `services/api/internal/postgres/capacity.go`
- Corresponding test files

# Required work

1. Run `git status --short` and inspect the complete diff. Do not overwrite or revert unrelated user changes.
2. Verify that the implementation matches the summary above. Treat the code and tests as evidence if this summary differs from the working tree.
3. Remove every code comment introduced by Codex in these changes. Use the diff to identify added `//`, block comments, JSX comments, and HTML comments. Preserve comments that existed before the current diff, license headers, build directives, generated markers, and comments required by external tooling.
4. Do not replace removed comments with new comments. Keep names and code structure clear enough to explain the behavior.
5. Preserve all implemented behavior while cleaning comments. Do not perform unrelated refactors.
6. Run only affected checks:
   - Web component tests for Add Person, Add Role, Upload Timesheet, and People Capacity.
   - Web ESLint for touched TypeScript files.
   - Web TypeScript check.
   - Go tests for `internal/capacity/importfile`, `internal/capacity`, `internal/httpapi`, and `internal/postgres`.
   - `git diff --check`.
7. Report which Codex-added comments were removed, which checks passed, and any remaining blocker. Do not commit or push unless explicitly requested.

Additional focus from the caller: $ARGUMENTS

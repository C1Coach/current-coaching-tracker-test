# CURRENT — coordinated update

## Before deploying

1. **Back up your existing Supabase database.** Keep the existing project, accounts and records. Do **not** rerun `schema.sql` or `migration_parent_accounts.sql`.
2. In Supabase **SQL Editor**, run `migration_current_update.sql` once, after reviewing the SQL. It adds the coach session library, scheduled target labels, private file storage and assigned-coach permissions.
3. The new migration must succeed before deploying the frontend. If it fails, stop and share the error; do not rerun the entire original schema.
4. Copy the updated project files into the **existing cloned GitHub repository**. Keep `.git` and `.github/workflows/deploy.yml` intact. The ZIP contains the workflow for reference. Do not copy `node_modules` or credentials.
5. Run `npm install` and `npm run build` in the repository on your PC. Only commit/push after the build succeeds. GitHub Actions will also run the build and publish `dist`.
6. Verify GitHub Actions succeeded. Open `https://c1coach.github.io/current-coaching-tracker/` on desktop and mobile. Remove the old broken home-screen shortcut before installing the new PWA.

## Important: validation limits

The JSX source was syntax-parsed successfully, and the service worker passed JavaScript syntax checking. A full Vite build could not be executed in the authoring environment because npm dependency installation timed out. **Do not treat this package as production-verified** until the local build and live tests below pass.

## Test before giving CURRENT to under-18s

- Coach: two assigned athletes show up, targets are independent, scheduled future target takes effect on the selected Monday, cancel/edit future target works, historical targets are preserved.
- Athlete: category progress caps each category at its target; log/edit S&C and on-water sets; Home/Gym filtering and coach restrictions; all 73 spreadsheet exercises present.
- Coach: view RPE by category and date range; inspect sets and reps; correct an athlete's training log; check revision audit (if installed).
- Library: coach uploads a PDF and DOCX, edits display name before upload, athlete opens each, athlete cannot upload/delete; unrelated logged-out user cannot access the files. The app does **not** populate training logs automatically.
- Parent: Dave sees only Alex; a second parent sees only their linked athlete; neither can update training, targets, exercise permissions or library files, **including through API calls**.
- Account: password recovery link opens password-change screen; logged-in password change works.
- PWA: Android offers installation and launches without 404; iPhone Safari Add to Home Screen launches in standalone mode; new GitHub deployments update the app.

## Known boundaries

- This update adds **online** session-library uploads, not offline training logging. Offline-first saving/syncing remains a separate future feature.
- Session-library files are visible to **all authenticated CURRENT accounts**, not individually assigned to specific athletes. If the library should be squad-specific, restrict access before uploading sensitive material.
- The spreadsheet includes a note that the second glute-bridge variant is provisional; review the exercise classifications before prescribing.
- PWA installation is device/browser-dependent. Actual Android and iPhone tests are required.
- The migration was designed for the provided existing schema and parent-account migration, but the live database schema was not accessible for inspection. If there is a policy or schema mismatch, stop and reconcile it rather than forcing the migration.

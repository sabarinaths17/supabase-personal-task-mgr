# Sab's Task Manager — Dev Notes

Personal Flutter + Supabase task manager. Single-user, cross-platform (Windows desktop + Android). See `README.md` for feature overview and setup steps.

## Current status (as of 2026-10-10)

**Android v1 APK built and ready** at `build/app/outputs/flutter-apk/app-release.apk` (56.5 MB).
Signed with debug keys (fine for personal use; see below if you need release signing).

### What's built and ready
- Auth (login/logout)
- Dashboard — greeting banner, quick-stat pills, tappable sections (Overdue, Today, WIP, Upcoming, Routines, Projects, By Status), today's routines summary with "View all" link
- Tasks tab — search bar, status filter chips, priority filter chips, sort menu, list/grid toggle, delete (long-press → status picker → Delete, or trash icon in task detail)
- Task detail — edit title/status/due date/notes (Markdown with preview), waiting_for_note field (shows when status = waiting_for), subtasks (add, tap to edit/delete, toggle), delete task button in app bar, save-on-back
- Calendar tab
- Projects tab — list (expandable, Edit/Delete buttons inside) + grid (long-press for actions), description field added
- Charts tab
- Routines tab — full CRUD (add/edit/delete), fields: title, active toggle, days of week, time, location, start/end date, notes; split into Today / Other Days sections
- Confetti + checkmark animation on task completion
- Realtime sync for all three tables
- **Android notifications** — 9am morning digest (overdue + due today), "due tomorrow" per-task reminders, background refresh via WorkManager every 12h

### Windows desktop
- **Windows EXE built** at `build\windows\x64\runner\Release\task_manager.exe`
- **Inno Setup installer script** at `installer.iss` — compile with Inno Setup 7 to produce `installer_output\TaskManager_v1.0.0_Setup.exe`
- WorkManager + NotificationService are guarded with `Platform.isAndroid` so they're silently skipped on Windows (workmanager is Android-only and crashes otherwise)
- Installer installs to `Program Files` (64-bit) — uses `{autopf64}` + `ArchitecturesInstallIn64BitMode=x64compatible`

### Not yet started / next steps
- End-to-end test on a real Android device
- Grant "Alarms & Reminders" permission on Android 12+ for exact-time notifications
- Optional: proper release signing (keystore) if distributing outside sideloading
- v2: quick-add task input (type title + Enter, no dialog) like Microsoft To Do
- v2: in-app due date alert on login (banner listing overdue + due today tasks)

## Supabase keep-alive
The free tier pauses projects after 7 days of inactivity. Options:
- **cron-job.org** (recommended): free cloud cron, ping `https://pwbixytthehwqelhgqdo.supabase.co` every 3 days — works even when PC is off
- **PowerShell + Task Scheduler**: `Invoke-WebRequest -Uri "https://pwbixytthehwqelhgqdo.supabase.co" -UseBasicParsing | Out-Null` scheduled every 3 days — only works when PC is on
- **Manual**: restore via Supabase dashboard when it pauses (~30 seconds)

## Android setup (added 2026-09-29)

### New files / changes
- `android/app/src/main/AndroidManifest.xml` — added INTERNET (was only in debug manifest!), POST_NOTIFICATIONS, SCHEDULE_EXACT_ALARM, RECEIVE_BOOT_COMPLETED, VIBRATE permissions; Supabase deep-link intent filter
- `android/app/build.gradle.kts` — added `isCoreLibraryDesugaringEnabled = true` + `desugar_jdk_libs` dependency (required by flutter_local_notifications)
- `lib/services/notification_service.dart` — NotificationService: init, requestPermission, scheduleTaskNotifications
- `lib/main.dart` — added WorkManager init + periodic background task; NotificationService.init() in main(); scheduleTaskNotifications() called after every _loadAll()
- `pubspec.yaml` — added flutter_local_notifications ^18.0.0, timezone ^0.10.0, workmanager ^0.10.0
- `assets/icon/app_icon.png` — generated icon (indigo + white checkmark); `tool/gen_icon.dart` is the generator script

### Build the APK
```
cd task_manager
flutter build apk --release --build-name=1.0.0 --build-number=1
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Install on device
```
flutter install
# or: adb install build/app/outputs/flutter-apk/app-release.apk
```

### Notifications gotchas
- Android 12+ (API 31+): user must grant "Alarms & Reminders" in Settings → Apps → Task Manager for exact-time reminders. The app doesn't currently prompt for this — user has to do it manually if reminders don't fire.
- Android 13+ (API 33+): POST_NOTIFICATIONS permission is requested at runtime on first app launch (standard system dialog).
- WorkManager minimum interval is 15 minutes; we use 12 hours for battery-friendliness. The background task re-initializes Supabase (restores session from SharedPreferences) and reschedules all notifications.
- The Flutter build tool rewrites `build.gradle.kts` on some builds ("Upgrading build.gradle.kts"). If it ever reverts the desugaring config, re-add `isCoreLibraryDesugaringEnabled = true` and the `dependencies { coreLibraryDesugaring(...) }` block.

## Architecture

- `lib/main.dart` — app entry, Supabase init, auth gate, login screen, and `HomeScreen` (dashboard/tasks/calendar/projects/charts/routines tabs).
- `lib/models/task.dart`, `lib/models/project.dart`, `lib/models/routine.dart` — plain data models with `fromMap` factories matching Supabase table columns.
- `lib/screens/task_detail_screen.dart` — task detail/edit, notes, subtasks (tappable for edit/delete), waiting_for_note field, delete task.
- `lib/screens/routines_screen.dart` — full CRUD for daily routines/habits. Exposes `RoutinesScreen.showDialog_()` static for opening the add/edit dialog from anywhere (e.g. HomeScreen FAB).
- `lib/screens/infographics_screen.dart` — chart view.
- `lib/theme/app_themes.dart`, `lib/theme/status_colors.dart` — theme + status/priority color mapping.

State is loaded once via `_loadAll()` and kept fresh through three Supabase Realtime channel subscriptions (`public:tasks`, `public:projects`, `public:routines`) in `HomeScreen.initState`, torn down in `dispose()`.

## Supabase schema

### `routines`
| column | type | notes |
|---|---|---|
| `id` | uuid, PK | |
| `title` | text | required |
| `notes` | text | nullable |
| `time_of_day` | time | nullable |
| `location` | text | nullable |
| `days_of_week` | int[] | empty array = every day; 1=Mon..7=Sun |
| `start_date` | date | nullable |
| `end_date` | date | nullable |
| `is_active` | boolean | default true |
| `user_id` | uuid | FK → auth.users, cascade delete |
| `created_at` | timestamptz | default now() |

### `tasks`
| column | type | notes |
|---|---|---|
| `id` | uuid, PK | |
| `title` | text | required |
| `notes` | text | nullable, basic Markdown |
| `due_date` | date | nullable |
| `status` | text | one of `kStatuses` in `task.dart`: `todo`, `wip`, `pending`, `lazy`, `never_gonna_happen`, `idk`, `cancelled`, `completed`, `waiting_for` |
| `priority` | text | `low` / `medium` / `high`, default `medium` |
| `waiting_for_note` | text | nullable, only meaningful when `status = 'waiting_for'` |
| `project_id` | uuid, FK → `projects.id` | nullable |
| `parent_task_id` | uuid, FK → `tasks.id` | nullable; non-null marks it as a subtask |
| `user_id` | uuid | set to `auth.uid()` on insert |
| `created_at` | timestamptz | default now() |
| `completed_at` | timestamptz | nullable, set when status becomes `completed` |

### `projects`
| column | type | notes |
|---|---|---|
| `id` | uuid, PK | |
| `name` | text | required |
| `description` | text | nullable |
| `due_date` | date | nullable |
| `priority` | text | `low` / `medium` / `high`, default `medium` |
| `user_id` | uuid | set to `auth.uid()` on insert |
| `created_at` | timestamptz | default now() |

### RLS
All three tables use row-level security scoped to `user_id = auth.uid()`. This is a single-user app — no multi-tenant sharing logic exists in the client.

## Gotchas

- The Supabase publishable/anon key lives inline in `main.dart` (`Supabase.initialize`). It's the public anon key (safe to expose client-side; RLS is the actual access boundary), not a secret.
- Use `publishableKey:` when calling `Supabase.initialize` — `anonKey:` is deprecated and will be removed.
- Realtime channels must be unsubscribed in `dispose()` (`supabase.removeChannel`); leaving them running duplicates callbacks on rebuild. `HomeScreen` manages three channels (tasks, projects, routines); `TaskDetailScreen` manages one (subtasks of the open task).
- Dashboard quick-stat pills and section headers (Overdue/Today/In Progress/Upcoming/Routines/By Status) are tappable and jump to the Tasks or Routines tab pre-filtered. Status/due filter state lives in `_statusFilter` + `_dueFilter` in `HomeScreen`. The app-bar back arrow (driven by `_previousTabIndex`) returns to the Dashboard and clears filters. A routines summary section in the dashboard shows today's active routines with a "View all" link.
- All Supabase writes go through a local `_mutate()` helper (one copy in `main.dart`, one in `task_detail_screen.dart`, one in `routines_screen.dart`) that catches exceptions and shows a red SnackBar. The one in `main.dart` also forces an immediate reload.
- `TaskDetailScreen` app-bar back arrow and check icon both call `_saveAndClose()`. A trash icon (delete task + subtasks) is also in the app bar. If you add more exit paths, route them through `_saveAndClose()`.
- Task detail screen shows a `waiting_for_note` text field when status is `waiting_for`. The field is saved as part of `_save()`.
- Subtask rows in task detail are tappable — opens an edit dialog (title, status, due date, delete).
- "Terminal" task states (`completed` and `cancelled`, see `Task.isTerminal`) are treated as "done" for checkbox display, strikethrough, and subtask counts. Toggling a terminal task's checkbox off resets it to `todo`.
- Tasks tab has search bar, status filter chips, priority filter chips, sort menu (date added / due date / priority / title A–Z), and list/grid toggle. Search and priority filter apply to the completed section too (via `_filteredCompletedSection`).
- Projects have description, priority, due date — all editable via Edit button in the expanded list view or long-press in grid view. Delete project leaves its tasks orphaned (project_id dangling) which the UI handles gracefully.
- Completing a task triggers both an animated green checkmark overlay AND confetti (`ConfettiController` in `HomeScreen`).
- `Routine.isActiveToday` returns true when `isActive == true` AND today's weekday is in `daysOfWeek` (or `daysOfWeek` is empty, meaning every day). `time_of_day` is a Postgres `time` column, returned as a `'HH:mm:ss'` string and parsed to `TimeOfDay`. `days_of_week` is `int[]`, sent/received as `List<int>`.
- Date display uses `_dateStr(DateTime d)` (padded `YYYY-MM-DD`) defined as a top-level function in each file that needs it — not a shared utility.

## Repo

- Remote: `https://github.com/sabarinaths17/supabase-personal-task-mgr.git`
- This `task_manager/` folder is the git root (not the parent `sab-task-mgr/` folder).

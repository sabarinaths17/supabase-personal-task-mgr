# Sab's Task Manager — Dev Notes

Personal Flutter + Supabase task manager. Single-user, cross-platform (Windows desktop + Android). See `README.md` for feature overview and setup steps.

## Architecture

- `lib/main.dart` — app entry, Supabase init, auth gate, login screen, and `HomeScreen` (dashboard/tasks/calendar/projects/charts tabs).
- `lib/models/task.dart`, `lib/models/project.dart` — plain data models with `fromMap` factories matching the Supabase table columns.
- `lib/screens/task_detail_screen.dart` — task detail/edit, notes, subtasks.
- `lib/screens/infographics_screen.dart` — chart view.
- `lib/theme/app_themes.dart`, `lib/theme/status_colors.dart` — theme + status/priority color mapping.

State is loaded once via `_loadAll()` and kept fresh through two Supabase Realtime channel subscriptions (`public:tasks`, `public:projects`) set up in `HomeScreen.initState` and torn down in `dispose()` via `supabase.removeChannel(...)`.

## Supabase schema

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
Both tables use row-level security scoped to `user_id = auth.uid()`. This is a single-user app — no multi-tenant sharing logic exists in the client.

### Known schema gap (needs a manual fix in the Supabase SQL editor)
The live `projects` table is missing the `due_date` column that the client (and the table above) assumes exists — creating a project fails with:
```
PostgrestException(message: Could not find the 'due_date' column of 'projects' in the schema cache, code: PGRST204, ...)
```
Fix by running in the Supabase SQL editor:
```sql
alter table public.projects add column if not exists due_date date;
```
No local Supabase CLI/migrations are set up for this repo (checked — there's no `supabase/` folder), so schema changes have to be applied by hand in the dashboard; Claude cannot run this migration directly.

## Gotchas

- The Supabase publishable/anon key lives inline in `main.dart` (`Supabase.initialize`). It's the public anon key (safe to expose client-side; RLS is the actual access boundary), not a secret.
- Use `publishableKey:` when calling `Supabase.initialize` — `anonKey:` is deprecated and will be removed.
- Realtime channels must be unsubscribed in `dispose()` (`supabase.removeChannel`); leaving them running duplicates callbacks on rebuild. Both `HomeScreen` and `TaskDetailScreen` do this.
- Dashboard project list intentionally omits progress/status info (just name + task count) — full project detail lives on the Projects tab. Dashboard quick-stat pills and section headers (Overdue/Today/In Progress/Upcoming/By Status) are tappable and jump to the Tasks tab pre-filtered, via `_goToTasks()` in `main.dart` — status filtering reuses `_statusFilter`, date-based filtering (overdue/today/upcoming) is a separate `_dueFilter` dimension shown as a "Filtered: X · Clear" banner. The app-bar back arrow (driven by `_previousTabIndex`) returns to the Dashboard and clears both filters.
- All Supabase writes (add/update task or project, toggle complete, subtask add/toggle) go through a local `_mutate()` helper (one copy in `main.dart`, one in `task_detail_screen.dart`) that catches exceptions and shows a red SnackBar, and forces an immediate reload rather than relying solely on the realtime callback. This exists because Postgres/PostgREST can silently no-op a write that an RLS policy rejects (no exception raised) or an insert can throw a schema-cache error like the one above — without this wrapper those failures were previously invisible ("nothing happens").
- `TaskDetailScreen`'s app-bar **back arrow now saves before closing**, same as the checkmark button — previously it just called `Navigator.pop` and silently discarded any status/notes/date change made in that screen. If you add more exit paths from that screen, route them through `_saveAndClose()`.
- "Terminal" task states (`completed` and `cancelled`, see `Task.isTerminal`) are both treated as "done" for checkbox display, strikethrough styling, and subtask completed-counts — not just `status == 'completed'`. Toggling a terminal task's checkbox off resets it to `todo`.

## Repo

- Remote: `https://github.com/sabarinaths17/supabase-personal-task-mgr.git`
- This `task_manager/` folder is the git root (not the parent `sab-task-mgr/` folder).

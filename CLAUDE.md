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

## Gotchas

- The Supabase publishable/anon key lives inline in `main.dart` (`Supabase.initialize`). It's the public anon key (safe to expose client-side; RLS is the actual access boundary), not a secret.
- Use `publishableKey:` when calling `Supabase.initialize` — `anonKey:` is deprecated and will be removed.
- Realtime channels must be unsubscribed in `dispose()` (`supabase.removeChannel`); leaving them running duplicates callbacks on rebuild.
- Dashboard project list intentionally omits progress/status info (just name + task count) — full project detail lives on the Projects tab.

## Repo

- Remote: `https://github.com/sabarinaths17/supabase-personal-task-mgr.git`
- This `task_manager/` folder is the git root (not the parent `sab-task-mgr/` folder).

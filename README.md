# Sab's Task Manager

A personal task management app built with Flutter, syncing in realtime across Windows desktop and Android via Supabase.

## Features

- **Cross-platform**: single Flutter codebase → Windows `.exe` + Android `.apk`
- **Realtime sync**: changes made on one device appear instantly on the other
- **Custom task statuses**: To-do, WIP, Pending, Lazy, Never Gonna Happen, IDK, Cancelled, Completed, Waiting For (with a linked note field for what it's waiting on)
- **Projects**: group tasks under projects, with sub-task support
- **Calendar view**: tasks plotted on their due dates, with day-by-day breakdown
- **Dashboard**: daily summary + breakdown by status and project
- **Infographics**: bar charts with selectable X-axis (status / project / due date week)
- **Task detail view**: rich notes with basic Markdown formatting (preview toggle), due date editing, status changes, subtask management
- **Completion animation**: confetti celebration when a task is marked complete
- **Themes**: Light, Dark, Grey, and a custom Claude-inspired theme

## Tech Stack

- **Frontend**: Flutter (Dart) — targeting Windows desktop and Android
- **Backend**: [Supabase](https://supabase.com) (Postgres database, Auth, Realtime)
- **Key packages**: `supabase_flutter`, `table_calendar`, `fl_chart`, `confetti`, `flutter_markdown`

## Getting Started

### Prerequisites
- Flutter SDK (stable channel)
- Android Studio (for Android SDK/build tools)
- Visual Studio Community with "Desktop development with C++" workload (for Windows builds)

### Setup
1. Clone this repo
2. Run `flutter pub get`
3. Ensure your Supabase project URL and anon key are set in `lib/main.dart`
4. Run on Windows: `flutter run -d windows`
5. Run on Android: connect a device/emulator, then `flutter run -d android`

### Database Schema
See `CLAUDE.md` for the full Supabase schema (`tasks` and `projects` tables) and RLS policy setup.

## Project Structure

```
lib/
├── main.dart                     # App entry, auth, home screen with tabs
├── models/
│   ├── task.dart                 # Task model + status constants
│   └── project.dart              # Project model
├── screens/
│   ├── task_detail_screen.dart   # Task detail/edit view with subtasks
│   └── infographics_screen.dart  # Chart view with axis selection
└── theme/
    └── app_themes.dart           # Light/Dark/Grey/Claude-ish theme definitions
```

## Status

Personal project, actively evolving. Not intended for public/multi-user use — built around a single-user Supabase auth setup.
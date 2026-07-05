import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:confetti/confetti.dart';
import 'package:table_calendar/table_calendar.dart';
import 'models/task.dart';
import 'models/project.dart';
import 'theme/app_themes.dart';
import 'screens/task_detail_screen.dart';
import 'screens/infographics_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://pwbixytthehwqelhgqdo.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB3Yml4eXR0aGVod3FlbGhncWRvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODMyMzA5NTcsImV4cCI6MjA5ODgwNjk1N30.woumFD3vG_JRJOlnb_h3fUAxEUyY8mMIgZ8ZBABR4n0',
  );

  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => MyAppState();

  static MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<MyAppState>()!;
}

class MyAppState extends State<MyApp> {
  AppThemeMode _mode = AppThemeMode.dark;

  void setThemeMode(AppThemeMode mode) => setState(() => _mode = mode);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager',
      theme: getTheme(_mode),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = supabase.auth.currentSession;
        if (session != null) return const HomeScreen();
        return const LoginScreen();
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() { _loading = true; _error = null; });
    try {
      await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Task Manager', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 32),
                TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
                const SizedBox(height: 16),
                TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder())),
                const SizedBox(height: 24),
                if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 16), child: Text(_error!, style: const TextStyle(color: Colors.red))),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _signIn,
                    child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Sign In'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Task> _tasks = [];
  List<Project> _projects = [];
  bool _loading = true;
  String? _statusFilter;
  int _tabIndex = 0;
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 1));
    _loadAll();

    supabase.channel('public:tasks').onPostgresChanges(
      event: PostgresChangeEvent.all, schema: 'public', table: 'tasks',
      callback: (payload) => _loadAll(),
    ).subscribe();

    supabase.channel('public:projects').onPostgresChanges(
      event: PostgresChangeEvent.all, schema: 'public', table: 'projects',
      callback: (payload) => _loadAll(),
    ).subscribe();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final taskData = await supabase.from('tasks').select().order('created_at', ascending: false);
    final projectData = await supabase.from('projects').select().order('created_at', ascending: false);
    if (!mounted) return;
    setState(() {
      _tasks = taskData.map<Task>((row) => Task.fromMap(row)).toList();
      _projects = projectData.map<Project>((row) => Project.fromMap(row)).toList();
      _loading = false;
    });
  }

  Future<void> _addTask(String title, {String? projectId, DateTime? dueDate}) async {
    await supabase.from('tasks').insert({
      'title': title,
      'user_id': supabase.auth.currentUser!.id,
      'project_id': projectId,
      'due_date': dueDate?.toIso8601String().split('T').first,
    });
  }

  Future<void> _toggleComplete(Task task, bool done) async {
    await supabase.from('tasks').update({
      'status': done ? 'completed' : 'todo',
      'completed_at': done ? DateTime.now().toIso8601String() : null,
    }).eq('id', task.id);
    if (done) _confettiController.play();
  }

  Future<void> _updateStatus(Task task, String newStatus, {String? waitingNote}) async {
    await supabase.from('tasks').update({
      'status': newStatus,
      'waiting_for_note': newStatus == 'waiting_for' ? waitingNote : null,
      'completed_at': newStatus == 'completed' ? DateTime.now().toIso8601String() : null,
    }).eq('id', task.id);
    if (newStatus == 'completed') _confettiController.play();
  }

  Future<void> _addProject(String name) async {
    await supabase.from('projects').insert({'name': name, 'user_id': supabase.auth.currentUser!.id});
  }

  void _openTaskDetail(Task task) {
    final subtasks = _tasks.where((t) => t.parentTaskId == task.id).toList();
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => TaskDetailScreen(
        task: task, subtasks: subtasks, supabase: supabase, onChanged: _loadAll,
      ),
    ));
  }

  void _showAddTaskDialog({String? presetProjectId}) {
    final controller = TextEditingController();
    String? selectedProjectId = presetProjectId;
    DateTime? selectedDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Task'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'Task title')),
              const SizedBox(height: 12),
              DropdownButton<String?>(
                isExpanded: true,
                hint: const Text('No project'),
                value: selectedProjectId,
                items: [
                  const DropdownMenuItem(value: null, child: Text('No project')),
                  ..._projects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
                ],
                onChanged: (val) => setDialogState(() => selectedProjectId = val),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(selectedDate == null ? 'Set due date' : '${selectedDate!.year}-${selectedDate!.month}-${selectedDate!.day}'),
                onPressed: () async {
                  final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
                  if (picked != null) setDialogState(() => selectedDate = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  _addTask(controller.text.trim(), projectId: selectedProjectId, dueDate: selectedDate);
                }
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddProjectDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Project'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'Project name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () { if (controller.text.trim().isNotEmpty) _addProject(controller.text.trim()); Navigator.pop(context); }, child: const Text('Add')),
        ],
      ),
    );
  }

  void _showStatusPicker(Task task) {
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: kStatuses.map((s) {
          return ListTile(
            title: Text(statusLabel(s)),
            trailing: task.status == s ? const Icon(Icons.check) : null,
            onTap: () async {
              Navigator.pop(context);
              if (s == 'waiting_for') {
                final noteController = TextEditingController(text: task.waitingForNote);
                final note = await showDialog<String>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Waiting for what?'),
                    content: TextField(controller: noteController, autofocus: true),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(context, noteController.text), child: const Text('Save')),
                    ],
                  ),
                );
                if (note != null) _updateStatus(task, s, waitingNote: note);
              } else {
                _updateStatus(task, s);
              }
            },
          );
        }).toList(),
      ),
    );
  }

  Map<String, int> get _statusCounts {
    final counts = <String, int>{};
    for (final t in _tasks) {
      counts[t.status] = (counts[t.status] ?? 0) + 1;
    }
    return counts;
  }

  int get _completedToday {
    final now = DateTime.now();
    return _tasks.where((t) => t.completedAt != null && t.completedAt!.year == now.year && t.completedAt!.month == now.month && t.completedAt!.day == now.day).length;
  }

  List<Task> get _activeTasks => _tasks.where((t) => !t.isTerminal && t.parentTaskId == null).toList();
  List<Task> get _completedSection => _tasks.where((t) => t.isTerminal && t.parentTaskId == null).toList();

  List<Task> get _filteredActiveTasks {
    if (_statusFilter == null) return _activeTasks;
    if (_statusFilter == 'completed' || _statusFilter == 'cancelled') {
      return _completedSection.where((t) => t.status == _statusFilter).toList();
    }
    return _activeTasks.where((t) => t.status == _statusFilter).toList();
  }

  Widget _taskTile(Task task) {
    final project = _projects.where((p) => p.id == task.projectId);
    return ListTile(
      leading: Checkbox(
        value: task.status == 'completed',
        onChanged: (val) => _toggleComplete(task, val ?? false),
      ),
      title: Text(task.title, style: task.status == 'completed' ? const TextStyle(decoration: TextDecoration.lineThrough) : null),
      subtitle: Text([
        statusLabel(task.status),
        if (task.status == 'waiting_for' && task.waitingForNote != null) '(${task.waitingForNote})',
        if (project.isNotEmpty) project.first.name,
        if (task.dueDate != null) '${task.dueDate!.year}-${task.dueDate!.month}-${task.dueDate!.day}',
      ].join(' · ')),
      onTap: () => _openTaskDetail(task),
      onLongPress: () => _showStatusPicker(task),
    );
  }

  Widget _buildDashboard() {
    final counts = _statusCounts;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Today', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('$_completedToday completed today · ${_tasks.length} total tasks'),
          const SizedBox(height: 24),
          Text('By Status', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: kStatuses.map((s) => Chip(label: Text('${statusLabel(s)}: ${counts[s] ?? 0}'))).toList()),
          const SizedBox(height: 24),
          Text('By Project', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ..._projects.map((p) {
            final count = _tasks.where((t) => t.projectId == p.id).length;
            return ListTile(title: Text(p.name), trailing: Text('$count tasks'), contentPadding: EdgeInsets.zero);
          }),
        ],
      ),
    );
  }

  Widget _buildTaskList() {
    final completed = _completedSection;
    return Column(
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: ChoiceChip(label: const Text('All'), selected: _statusFilter == null, onSelected: (_) => setState(() => _statusFilter = null))),
              ...kStatuses.map((s) => Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: ChoiceChip(label: Text(statusLabel(s)), selected: _statusFilter == s, onSelected: (_) => setState(() => _statusFilter = s)))),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              if (_statusFilter == null || (_statusFilter != 'completed' && _statusFilter != 'cancelled'))
                ..._filteredActiveTasks.map(_taskTile),
              if (_statusFilter == null) ...[
                if (completed.isNotEmpty)
                  ExpansionTile(
                    title: Text('Completed (${completed.length})'),
                    children: completed.map(_taskTile).toList(),
                  ),
              ] else if (_statusFilter == 'completed' || _statusFilter == 'cancelled') ...[
                ..._filteredActiveTasks.map(_taskTile),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCalendar() {
    final dayKey = (DateTime d) => DateTime(d.year, d.month, d.day);
    final tasksForDay = _tasks.where((t) => t.dueDate != null && dayKey(t.dueDate!) == dayKey(_selectedDay)).toList();

    return Column(
      children: [
        TableCalendar(
          firstDay: DateTime(2020),
          lastDay: DateTime(2100),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => dayKey(day) == dayKey(_selectedDay),
          onDaySelected: (selected, focused) => setState(() { _selectedDay = selected; _focusedDay = focused; }),
          eventLoader: (day) => _tasks.where((t) => t.dueDate != null && dayKey(t.dueDate!) == dayKey(day)).toList(),
          calendarFormat: CalendarFormat.month,
        ),
        const Divider(),
        Expanded(
          child: tasksForDay.isEmpty
              ? const Center(child: Text('No tasks for this day.'))
              : ListView(children: tasksForDay.map(_taskTile).toList()),
        ),
      ],
    );
  }

  Widget _buildProjects() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: _projects.map((p) {
        final projectTasks = _tasks.where((t) => t.projectId == p.id && t.parentTaskId == null).toList();
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            title: Text(p.name),
            subtitle: Text('${projectTasks.length} tasks'),
            children: [
              ...projectTasks.map(_taskTile),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Add task to this project'),
                onTap: () => _showAddTaskDialog(presetProjectId: p.id),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildDashboard(),
      _buildTaskList(),
      _buildCalendar(),
      _buildProjects(),
      InfographicsScreen(tasks: _tasks, projects: _projects),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Manager'),
        actions: [
          PopupMenuButton<AppThemeMode>(
            icon: const Icon(Icons.palette),
            onSelected: (mode) => MyApp.of(context).setThemeMode(mode),
            itemBuilder: (context) => AppThemeMode.values.map((m) => PopupMenuItem(value: m, child: Text(themeName(m)))).toList(),
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: () => supabase.auth.signOut()),
        ],
      ),
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          _loading ? const Center(child: CircularProgressIndicator()) : pages[_tabIndex],
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            numberOfParticles: 30,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet(
          context: context,
          builder: (context) => SafeArea(
            child: Wrap(children: [
              ListTile(leading: const Icon(Icons.task), title: const Text('Add Task'), onTap: () { Navigator.pop(context); _showAddTaskDialog(); }),
              ListTile(leading: const Icon(Icons.folder), title: const Text('Add Project'), onTap: () { Navigator.pop(context); _showAddProjectDialog(); }),
            ]),
          ),
        ),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.list), label: 'Tasks'),
          NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Calendar'),
          NavigationDestination(icon: Icon(Icons.folder), label: 'Projects'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Charts'),
        ],
      ),
    );
  }
}
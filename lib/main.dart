import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'models/task.dart';
import 'models/project.dart';
import 'theme/app_themes.dart';
import 'theme/status_colors.dart';
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
    setState(() {
      _loading = true;
      _error = null;
    });
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
                if (_error != null)
                  Padding(padding: const EdgeInsets.only(bottom: 16), child: Text(_error!, style: const TextStyle(color: Colors.red))),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _signIn,
                    child: _loading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Sign In'),
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
  bool _taskGridView = false;
  bool _projectGridView = false;
  bool _showSubtasksOnlyToday = false;

  @override
  void initState() {
    super.initState();
    _loadAll();

    supabase.channel('public:tasks').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'tasks',
      callback: (payload) => _loadAll(),
    ).subscribe();

    supabase.channel('public:projects').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'projects',
      callback: (payload) => _loadAll(),
    ).subscribe();
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

  Future<void> _addTask(String title, {String? projectId, DateTime? dueDate, String priority = 'medium'}) async {
    await supabase.from('tasks').insert({
      'title': title,
      'user_id': supabase.auth.currentUser!.id,
      'project_id': projectId,
      'due_date': dueDate?.toIso8601String().split('T').first,
      'priority': priority,
    });
  }

  Future<void> _toggleComplete(Task task, bool done) async {
    await supabase.from('tasks').update({
      'status': done ? 'completed' : 'todo',
      'completed_at': done ? DateTime.now().toIso8601String() : null,
    }).eq('id', task.id);
    if (done && mounted) _showCompletionAnimation();
  }

  Future<void> _updateStatus(Task task, String newStatus, {String? waitingNote}) async {
    await supabase.from('tasks').update({
      'status': newStatus,
      'waiting_for_note': newStatus == 'waiting_for' ? waitingNote : null,
      'completed_at': newStatus == 'completed' ? DateTime.now().toIso8601String() : null,
    }).eq('id', task.id);
    if (newStatus == 'completed' && mounted) _showCompletionAnimation();
  }

  void _showCompletionAnimation() {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Center(child: _CompletionCheckmark(onDone: () => entry.remove())),
    );
    overlay.insert(entry);
  }

  Future<void> _addProject(String name, {DateTime? dueDate, String priority = 'medium'}) async {
    await supabase.from('projects').insert({
      'name': name,
      'user_id': supabase.auth.currentUser!.id,
      'due_date': dueDate?.toIso8601String().split('T').first,
      'priority': priority,
    });
  }

  void _openTaskDetail(Task task) {
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => TaskDetailScreen(task: task, supabase: supabase, onChanged: _loadAll),
    ));
  }

  void _showAddTaskDialog({String? presetProjectId}) {
    final controller = TextEditingController();
    String? selectedProjectId = presetProjectId;
    DateTime? selectedDate;
    String selectedPriority = 'medium';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Task'),
          content: SingleChildScrollView(
            child: Column(
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
                Wrap(
                  spacing: 8,
                  children: kPriorities.map((p) => ChoiceChip(
                    label: Text(p),
                    selected: selectedPriority == p,
                    selectedColor: priorityColor(p).withValues(alpha: 0.3),
                    onSelected: (_) => setDialogState(() => selectedPriority = p),
                  )).toList(),
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
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  _addTask(controller.text.trim(), projectId: selectedProjectId, dueDate: selectedDate, priority: selectedPriority);
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
    DateTime? selectedDate;
    String selectedPriority = 'medium';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Project'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'Project name')),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: kPriorities.map((p) => ChoiceChip(
                  label: Text(p),
                  selected: selectedPriority == p,
                  selectedColor: priorityColor(p).withValues(alpha: 0.3),
                  onSelected: (_) => setDialogState(() => selectedPriority = p),
                )).toList(),
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
                if (controller.text.trim().isNotEmpty) _addProject(controller.text.trim(), dueDate: selectedDate, priority: selectedPriority);
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        ),
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
            leading: Container(width: 12, height: 12, decoration: BoxDecoration(color: statusColor(s), shape: BoxShape.circle)),
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
    for (final t in _tasks.where((t) => t.parentTaskId == null)) {
      counts[t.status] = (counts[t.status] ?? 0) + 1;
    }
    return counts;
  }

  int get _completedToday {
    final now = DateTime.now();
    return _tasks.where((t) => t.completedAt != null && t.completedAt!.year == now.year && t.completedAt!.month == now.month && t.completedAt!.day == now.day).length;
  }

  List<Task> get _subtasksDueToday {
    final now = DateTime.now();
    return _tasks.where((t) => t.parentTaskId != null && t.dueDate != null && t.dueDate!.year == now.year && t.dueDate!.month == now.month && t.dueDate!.day == now.day).toList();
  }

  List<Task> get _activeTasks => _tasks.where((t) => !t.isTerminal && t.parentTaskId == null).toList();
  List<Task> get _completedSection => _tasks.where((t) => t.isTerminal && t.parentTaskId == null).toList();

  int _subtaskCountFor(String taskId) => _tasks.where((t) => t.parentTaskId == taskId).length;
  int _subtaskCompletedCountFor(String taskId) => _tasks.where((t) => t.parentTaskId == taskId && t.status == 'completed').length;

  List<Task> get _filteredActiveTasks {
    if (_statusFilter == null) return _activeTasks;
    if (_statusFilter == 'completed' || _statusFilter == 'cancelled') {
      return _completedSection.where((t) => t.status == _statusFilter).toList();
    }
    return _activeTasks.where((t) => t.status == _statusFilter).toList();
  }

  Widget _statusBadge(String status, {double fontSize = 11}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: statusColor(status).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
      child: Text(statusLabel(status), style: TextStyle(fontSize: fontSize, color: statusColor(status), fontWeight: FontWeight.w600)),
    );
  }

  Widget _priorityDot(String priority) {
    return Container(width: 8, height: 8, decoration: BoxDecoration(color: priorityColor(priority), shape: BoxShape.circle));
  }

  Widget _taskCard(Task task) {
    final project = _projects.where((p) => p.id == task.projectId);
    final subCount = _subtaskCountFor(task.id);
    final subDone = _subtaskCompletedCountFor(task.id);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: statusColor(task.status).withValues(alpha: 0.5), width: 1.5),
      ),
      child: ListTile(
        leading: _HoverCheckbox(value: task.status == 'completed', onChanged: (val) => _toggleComplete(task, val)),
        title: Row(
          children: [
            _priorityDot(task.priority),
            const SizedBox(width: 6),
            Expanded(child: Text(task.title, style: task.status == 'completed' ? const TextStyle(decoration: TextDecoration.lineThrough) : null)),
          ],
        ),
        subtitle: Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _statusBadge(task.status),
            if (task.status == 'waiting_for' && task.waitingForNote != null) Text('(${task.waitingForNote})', style: const TextStyle(fontSize: 12)),
            if (task.dueDate != null) Text('📅 ${task.dueDate!.year}-${task.dueDate!.month}-${task.dueDate!.day}', style: const TextStyle(fontSize: 12)),
            if (project.isNotEmpty) Text(project.first.name, style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
            if (subCount > 0) Text('$subDone/$subCount subtasks', style: const TextStyle(fontSize: 12)),
          ],
        ),
        onTap: () => _openTaskDetail(task),
        onLongPress: () => _showStatusPicker(task),
      ),
    );
  }

  Widget _taskGridCard(Task task) {
    final subCount = _subtaskCountFor(task.id);
    final subDone = _subtaskCompletedCountFor(task.id);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: statusColor(task.status).withValues(alpha: 0.5), width: 1.5)),
      child: InkWell(
        onTap: () => _openTaskDetail(task),
        onLongPress: () => _showStatusPicker(task),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _priorityDot(task.priority),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, decoration: task.status == 'completed' ? TextDecoration.lineThrough : null),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              _statusBadge(task.status, fontSize: 9),
              const SizedBox(height: 3),
              if (task.dueDate != null)
                Text('${task.dueDate!.year}-${task.dueDate!.month}-${task.dueDate!.day}', style: const TextStyle(fontSize: 9), overflow: TextOverflow.ellipsis),
              if (subCount > 0) Text('$subDone/$subCount subtasks', style: const TextStyle(fontSize: 9)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _taskGrid(List<Task> tasks) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 170, mainAxisExtent: 130, crossAxisSpacing: 8, mainAxisSpacing: 8),
      itemCount: tasks.length,
      itemBuilder: (context, i) => _taskGridCard(tasks[i]),
    );
  }

  String _dashboardSummaryText() {
    final active = _activeTasks.length;
    final completedToday = _completedToday;
    final subToday = _subtasksDueToday.length;
    final projectsCount = _projects.length;
    final waiting = _tasks.where((t) => t.status == 'waiting_for').length;

    final buffer = StringBuffer();
    buffer.write('You have $active active task${active == 1 ? '' : 's'} across $projectsCount project${projectsCount == 1 ? '' : 's'}. ');
    buffer.write('$completedToday completed today');
    if (subToday > 0) buffer.write(', with $subToday subtask${subToday == 1 ? '' : 's'} due today');
    buffer.write('. ');
    if (waiting > 0) buffer.write('$waiting task${waiting == 1 ? '' : 's'} waiting on something external.');
    return buffer.toString();
  }

  Widget _statCard(String label, String value, Color color, IconData icon, {VoidCallback? onTap}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: color.withValues(alpha: 0.4), width: 1.5)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 8),
              Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              Text(label, style: const TextStyle(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    final counts = _statusCounts;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primary.withValues(alpha: 0.85), Theme.of(context).colorScheme.secondary.withValues(alpha: 0.85)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Text('Just. Do. It.', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.2)),
            ),
          ),
          const SizedBox(height: 16),
          Text(_dashboardSummaryText(), style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.5,
            children: [
              _statCard('Active Tasks', '${_activeTasks.length}', const Color(0xFF5B8DEF), Icons.list_alt),
              _statCard('Completed Today', '$_completedToday', const Color(0xFF4CAF50), Icons.check_circle),
              _statCard('Projects', '${_projects.length}', const Color(0xFF8B6DD1), Icons.folder),
              _statCard(
                'Subtasks Due Today', '${_subtasksDueToday.length}', const Color(0xFFF5A623), Icons.checklist,
                onTap: () => setState(() { _showSubtasksOnlyToday = true; _tabIndex = 1; }),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('By Status', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: kStatuses.map((s) => Chip(
              avatar: Container(width: 10, height: 10, decoration: BoxDecoration(color: statusColor(s), shape: BoxShape.circle)),
              label: Text('${statusLabel(s)}: ${counts[s] ?? 0}'),
              backgroundColor: statusColor(s).withValues(alpha: 0.1),
            )).toList(),
          ),
          const SizedBox(height: 24),
          Text('Overview Chart', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          SizedBox(height: 220, child: InfographicsScreen(allTasks: _tasks, projects: _projects, compact: true)),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.bar_chart),
              label: const Text('Full charts'),
              onPressed: () => setState(() => _tabIndex = 4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList() {
    if (_showSubtasksOnlyToday) {
      final subs = _subtasksDueToday;
      return Column(
        children: [
          ListTile(
            leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _showSubtasksOnlyToday = false)),
            title: const Text('Subtasks due today'),
          ),
          Expanded(
            child: subs.isEmpty ? const Center(child: Text('No subtasks due today.')) : ListView(children: subs.map(_taskCard).toList()),
          ),
        ],
      );
    }

    final completed = _completedSection;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: ChoiceChip(label: const Text('All'), selected: _statusFilter == null, onSelected: (_) => setState(() => _statusFilter = null))),
                    ...kStatuses.map((s) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            avatar: Container(width: 10, height: 10, decoration: BoxDecoration(color: statusColor(s), shape: BoxShape.circle)),
                            label: Text(statusLabel(s)),
                            selected: _statusFilter == s,
                            selectedColor: statusColor(s).withValues(alpha: 0.3),
                            onSelected: (_) => setState(() => _statusFilter = s),
                          ),
                        )),
                  ],
                ),
              ),
            ),
            IconButton(icon: Icon(_taskGridView ? Icons.view_list : Icons.grid_view), onPressed: () => setState(() => _taskGridView = !_taskGridView)),
          ],
        ),
        Expanded(
          child: _taskGridView
              ? _taskGrid(_filteredActiveTasks)
              : ListView(
                  children: [
                    if (_statusFilter == null || (_statusFilter != 'completed' && _statusFilter != 'cancelled')) ..._filteredActiveTasks.map(_taskCard),
                    if (_statusFilter == null) ...[
                      if (completed.isNotEmpty) ExpansionTile(title: Text('Completed (${completed.length})'), children: completed.map(_taskCard).toList()),
                    ] else if (_statusFilter == 'completed' || _statusFilter == 'cancelled') ...[
                      ..._filteredActiveTasks.map(_taskCard),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildCalendar() {
    final dayKey = (DateTime d) => DateTime(d.year, d.month, d.day);
    final tasksForDay = _tasks.where((t) => t.dueDate != null && t.parentTaskId == null && dayKey(t.dueDate!) == dayKey(_selectedDay)).toList();

    return Column(
      children: [
        TableCalendar(
          firstDay: DateTime(2020),
          lastDay: DateTime(2100),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => dayKey(day) == dayKey(_selectedDay),
          onDaySelected: (selected, focused) => setState(() { _selectedDay = selected; _focusedDay = focused; }),
          eventLoader: (day) => _tasks.where((t) => t.dueDate != null && t.parentTaskId == null && dayKey(t.dueDate!) == dayKey(day)).toList(),
          calendarFormat: CalendarFormat.month,
        ),
        const Divider(),
        Expanded(
          child: tasksForDay.isEmpty ? const Center(child: Text('No tasks for this day.')) : ListView(children: tasksForDay.map(_taskCard).toList()),
        ),
      ],
    );
  }

  Widget _projectGridCard(Project p) {
    final count = _tasks.where((t) => t.projectId == p.id && t.parentTaskId == null).length;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: priorityColor(p.priority).withValues(alpha: 0.5), width: 1.5)),
      child: InkWell(
        onTap: () => _showAddTaskDialog(presetProjectId: p.id),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [_priorityDot(p.priority), const SizedBox(width: 4), Expanded(child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis))]),
              const Spacer(),
              Text('$count tasks', style: const TextStyle(fontSize: 11)),
              if (p.dueDate != null) Text('${p.dueDate!.year}-${p.dueDate!.month}-${p.dueDate!.day}', style: const TextStyle(fontSize: 9)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProjects() {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(icon: Icon(_projectGridView ? Icons.view_list : Icons.grid_view), onPressed: () => setState(() => _projectGridView = !_projectGridView)),
        ),
        Expanded(
          child: _projectGridView
              ? GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 170, mainAxisExtent: 110, crossAxisSpacing: 8, mainAxisSpacing: 8),
                  itemCount: _projects.length,
                  itemBuilder: (context, i) => _projectGridCard(_projects[i]),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: _projects.map((p) {
                    final projectTasks = _tasks.where((t) => t.projectId == p.id && t.parentTaskId == null).toList();
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: priorityColor(p.priority).withValues(alpha: 0.4))),
                      child: ExpansionTile(
                        title: Row(children: [_priorityDot(p.priority), const SizedBox(width: 6), Text(p.name)]),
                        subtitle: Text('${projectTasks.length} tasks${p.dueDate != null ? ' · due ${p.dueDate!.year}-${p.dueDate!.month}-${p.dueDate!.day}' : ''}'),
                        children: [
                          ...projectTasks.map(_taskCard),
                          ListTile(leading: const Icon(Icons.add), title: const Text('Add task to this project'), onTap: () => _showAddTaskDialog(presetProjectId: p.id)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildDashboard(),
      _buildTaskList(),
      _buildCalendar(),
      _buildProjects(),
      InfographicsScreen(allTasks: _tasks, projects: _projects),
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
      body: _loading ? const Center(child: CircularProgressIndicator()) : pages[_tabIndex],
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
        onDestinationSelected: (i) => setState(() { _tabIndex = i; _showSubtasksOnlyToday = false; }),
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

class _HoverCheckbox extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _HoverCheckbox({required this.value, required this.onChanged});

  @override
  State<_HoverCheckbox> createState() => _HoverCheckboxState();
}

class _HoverCheckboxState extends State<_HoverCheckbox> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(color: _hovering ? Colors.green.withValues(alpha: 0.15) : Colors.transparent, shape: BoxShape.circle),
        child: Checkbox(value: widget.value, activeColor: Colors.green, onChanged: (val) => widget.onChanged(val ?? false)),
      ),
    );
  }
}

class _CompletionCheckmark extends StatefulWidget {
  final VoidCallback onDone;
  const _CompletionCheckmark({required this.onDone});

  @override
  State<_CompletionCheckmark> createState() => _CompletionCheckmarkState();
}

class _CompletionCheckmarkState extends State<_CompletionCheckmark> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.3, end: 1.2).chain(CurveTween(curve: Curves.easeOutBack)), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 40),
    ]).animate(_controller);
    _opacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_controller);
    _controller.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Opacity(
          opacity: _opacity.value,
          child: Transform.scale(
            scale: _scale.value,
            child: Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 56),
            ),
          ),
        ),
      ),
    );
  }
}
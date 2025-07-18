import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'mock_steps_provider.dart';
import 'dart:async';
import 'friends_screen.dart';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static _MyAppState? of(BuildContext context) => context.findAncestorStateOfType<_MyAppState>();

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isAuthenticated = false;
  bool _showLogin = true;
  String _theme = 'light';

  @override
  void initState() {
    super.initState();
    _checkAuth();
    _fetchTheme();
  }

  Future<void> _checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isAuthenticated = prefs.getString('jwt') != null;
    });
  }

  Future<void> _fetchTheme() async {
    final api = ApiService();
    final settings = await api.fetchSettings();
    setState(() {
      _theme = settings?.theme ?? 'light';
    });
  }

  void updateTheme(String theme) {
    setState(() {
      _theme = theme;
    });
  }

  void _onAuthenticated() {
    setState(() {
      _isAuthenticated = true;
    });
    _fetchTheme(); // Refetch theme after login
  }

  void _toggleAuthScreen() {
    setState(() {
      _showLogin = !_showLogin;
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt');
    setState(() {
      _isAuthenticated = false;
      _showLogin = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeData = _theme == 'dark'
        ? ThemeData.dark().copyWith(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
          )
        : ThemeData.light().copyWith(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.light),
          );
    if (!_isAuthenticated) {
      return MaterialApp(
        title: 'Healthy Summer',
        theme: themeData,
        home: _showLogin
            ? LoginScreen(onAuthenticated: _onAuthenticated, onSwitch: _toggleAuthScreen)
            : RegisterScreen(onRegistered: _onAuthenticated, onSwitch: _toggleAuthScreen),
      );
    }
    return MaterialApp(
      title: 'Healthy Summer',
      theme: themeData,
      home: MainNavigation(onLogout: _logout),
    );
  }
}

class LoginScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;
  final VoidCallback onSwitch;
  const LoginScreen({super.key, required this.onAuthenticated, required this.onSwitch});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';
  String? _error;
  bool _loading = false;
  final ApiService api = ApiService();

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    final token = await api.login(_email, _password);
    setState(() { _loading = false; });
    if (token != null) {
      final me = await api.getMe();
      if (me != null) {
        api.currentUserId = me.id;
      }
      widget.onAuthenticated();
    } else {
      setState(() { _error = 'Invalid credentials'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Email'),
                onChanged: (v) => _email = v,
                validator: (v) => v == null || v.isEmpty ? 'Enter email' : null,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                onChanged: (v) => _password = v,
                validator: (v) => v == null || v.isEmpty ? 'Enter password' : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 16),
              _loading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          _login();
                        }
                      },
                      child: const Text('Login'),
                    ),
              TextButton(
                onPressed: widget.onSwitch,
                child: const Text('No account? Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  final VoidCallback onRegistered;
  final VoidCallback onSwitch;
  const RegisterScreen({super.key, required this.onRegistered, required this.onSwitch});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _email = '';
  String _password = '';
  String? _error;
  bool _loading = false;
  final ApiService api = ApiService();

  Future<void> _register() async {
    setState(() { _loading = true; _error = null; });
    final success = await api.register(_name, _email, _password);
    setState(() { _loading = false; });
    if (success) {
      final token = await api.login(_email, _password);
      if (token != null) {
        widget.onRegistered();
      } else {
        setState(() { _error = 'Registration succeeded, but login failed.'; });
      }
    } else {
      setState(() { _error = 'Registration failed (email may be taken)'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Name'),
                onChanged: (v) => _name = v,
                validator: (v) => v == null || v.isEmpty ? 'Enter name' : null,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Email'),
                onChanged: (v) => _email = v,
                validator: (v) => v == null || v.isEmpty ? 'Enter email' : null,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                onChanged: (v) => _password = v,
                validator: (v) => v == null || v.isEmpty ? 'Enter password' : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 16),
              _loading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          _register();
                        }
                      },
                      child: const Text('Register'),
                    ),
              TextButton(
                onPressed: widget.onSwitch,
                child: const Text('Already have an account? Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  final VoidCallback? onLogout;
  const MainNavigation({super.key, this.onLogout});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  static List<Widget> _screensBuilder(VoidCallback? onLogout) => <Widget>[
    DashboardScreen(),
    FriendsScreen(),
    FeedScreen(), // new
    CombinedWorkoutsScreen(),
    WaterScreen(),
    StepsScreen(),
    DietScreen(),
    PeriodsScreen(),
    AwardsScreen(),
    HealthRecordsScreen(),
    RemindersScreen(),
    ProfileScreen(),
    SettingsScreen(),
  ];

  static const List<BottomNavigationBarItem> _navItems = [
    BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
    BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Friends'),
    BottomNavigationBarItem(icon: Icon(Icons.rss_feed), label: 'Feed'), // new
    BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: 'Workouts'),
    BottomNavigationBarItem(icon: Icon(Icons.local_drink), label: 'Water'),
    BottomNavigationBarItem(icon: Icon(Icons.directions_walk), label: 'Steps'),
    BottomNavigationBarItem(icon: Icon(Icons.restaurant), label: 'Diet'),
    BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Periods'),
    BottomNavigationBarItem(icon: Icon(Icons.emoji_events), label: 'Awards'),
    BottomNavigationBarItem(icon: Icon(Icons.health_and_safety), label: 'Health'),
    BottomNavigationBarItem(icon: Icon(Icons.alarm), label: 'Reminders'),
    BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
    BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final _screens = _screensBuilder(widget.onLogout);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Healthy Summer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: widget.onLogout,
          ),
        ],
      ),
      body: Center(child: _screens[_selectedIndex]),
      bottomNavigationBar: BottomNavigationBar(
        items: _navItems,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService api = ApiService();
  Map<String, dynamic>? _summary;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchSummary();
    _fetchUserProfile();
    _fetchSettings();
  }

  Future<void> _fetchSummary() async {
    setState(() { _loading = true; _error = null; });
    try {
      final summary = await api.fetchWeeklySummary();
      setState(() { _summary = summary; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Failed to load summary'; _loading = false; });
    }
  }

  Future<void> _fetchUserProfile() async {
    setState(() { _loading = true; });
    final user = await api.getMe();
    setState(() {
      _loading = false;
      if (user != null) {
      } else {
        _error = 'Failed to load user profile';
      }
    });
  }

  Future<void> _fetchSettings() async {
    setState(() { _loading = true; });
    final settings = await api.getSettings();
    setState(() {
      _loading = false;
      if (settings != null) {
      } else {
        _error = 'Failed to load settings';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }
    final s = _summary ?? {};
    final daily = (s['daily_calories'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('This Week', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          Row(
            children: [
              _SummaryCard(
                icon: Icons.directions_walk,
                label: 'Steps',
                value: s['steps']?.toString() ?? '-',
                color: Colors.blue,
              ),
              const SizedBox(width: 12),
              _SummaryCard(
                icon: Icons.fitness_center,
                label: 'Workouts',
                value: s['workouts']?.toString() ?? '-',
                color: Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _SummaryCard(
                icon: Icons.local_fire_department,
                label: 'Calories Burned',
                value: s['workout_calories']?.toString() ?? '-',
                color: Colors.red,
              ),
              const SizedBox(width: 12),
              _SummaryCard(
                icon: Icons.restaurant,
                label: 'Calories Consumed',
                value: s['diet_calories']?.toString() ?? '-',
                color: Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _SummaryCard(
                icon: Icons.local_drink,
                label: 'Water (ml)',
                value: s['water_ml']?.toString() ?? '-',
                color: Colors.cyan,
              ),
              const SizedBox(width: 12),
              _SummaryCard(
                icon: Icons.timer,
                label: 'Workout Minutes',
                value: s['workout_minutes']?.toString() ?? '-',
                color: Colors.purple,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Calories Burned vs Consumed', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: _CaloriesChart(daily: daily),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            onPressed: _fetchSummary,
          ),
        ],
      ),
    );
  }
}

class _CaloriesChart extends StatelessWidget {
  final List<Map<String, dynamic>> daily;
  const _CaloriesChart({required this.daily});

  @override
  Widget build(BuildContext context) {
    if (daily.isEmpty) {
      return const Center(child: Text('No data'));
    }
    final spotsBurned = <FlSpot>[];
    final spotsConsumed = <FlSpot>[];
    final labels = <String>[];
    for (var i = 0; i < daily.length; i++) {
      final d = daily[i];
      spotsBurned.add(FlSpot(i.toDouble(), (d['burned'] ?? 0).toDouble()));
      spotsConsumed.add(FlSpot(i.toDouble(), (d['consumed'] ?? 0).toDouble()));
      labels.add((d['date'] as String).substring(5));
    }
    return LineChart(
      LineChartData(
        minY: 0,
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 40),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= labels.length) return const SizedBox.shrink();
                return Text(labels[idx], style: const TextStyle(fontSize: 10));
              },
              interval: 1,
              reservedSize: 32,
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: true),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: spotsBurned,
            isCurved: true,
            color: Colors.red,
            barWidth: 3,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
            isStrokeCapRound: true,
          ),
          LineChartBarData(
            spots: spotsConsumed,
            isCurved: true,
            color: Colors.orange,
            barWidth: 3,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
            isStrokeCapRound: true,
          ),
        ],
        lineTouchData: LineTouchData(enabled: true),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _SummaryCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        color: color.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.black)),
            ],
          ),
        ),
      ),
    );
  }
}

class CombinedWorkoutsScreen extends StatefulWidget {
  CombinedWorkoutsScreen({super.key});

  @override
  State<CombinedWorkoutsScreen> createState() => _CombinedWorkoutsScreenState();
}

class _CombinedWorkoutsScreenState extends State<CombinedWorkoutsScreen> {
  final ApiService api = ApiService();
  List<Workout> _workouts = [];
  bool _loading = false;
  String? _error;
  bool _showForm = false;
  bool _formLoading = false;
  bool _editing = false;
  Workout? _editingWorkout;
  final _formKey = GlobalKey<FormState>();
  String _type = '';
  String _customType = '';
  String _duration = '';
  String _intensity = 'medium';
  String _calories = '';
  String _location = '';
  double? _userWeight;
  bool _caloriesManuallyEdited = false;
  String _category = '';
  String _customCategory = '';

  DateTime? _startDate;
  DateTime? _endDate;
  String _filterCategory = '';
  String _filterType = '';

  final List<String> _typeOptions = [
    'Running',
    'Swimming',
    'Gym',
    'Cycling',
    'Other',
  ];
  final List<String> _intensityOptions = [
    'low',
    'medium',
    'high',
  ];
  final List<String> _categoryOptions = [
    'Cardio',
    'Strength',
    'Flexibility',
    'Balance',
    'Other',
  ];
  final List<String> _filterCategoryOptions = [
    '', 'Cardio', 'Strength', 'Flexibility', 'Balance', 'Other',
  ];
  final List<String> _filterTypeOptions = [
    '', 'Running', 'Swimming', 'Gym', 'Cycling', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _startDate = today;
    _endDate = today;
    _fetchUserWeight();
    _fetchWorkouts();
  }

  Future<void> _fetchUserWeight() async {
    final user = await api.getMe();
    setState(() {
      _userWeight = user?.weight ?? 70;
    });
  }

  void _maybeAutoCalculateCalories() {
    final type = _type == 'Other' ? _customType : _type;
    if (!_typeOptions.contains(type) || type == 'Other' || _caloriesManuallyEdited) return;
    if (_duration.isEmpty || _intensity.isEmpty || _userWeight == null) return;
    final durationMin = int.tryParse(_duration) ?? 0;
    if (durationMin <= 0) return;
    double met = 0;
    switch (type.toLowerCase()) {
      case 'running':
        if (_intensity == 'low') met = 6.0;
        else if (_intensity == 'medium') met = 8.0;
        else if (_intensity == 'high') met = 12.0;
        break;
      case 'cycling':
        if (_intensity == 'low') met = 4.0;
        else if (_intensity == 'medium') met = 8.0;
        else if (_intensity == 'high') met = 12.0;
        break;
      case 'swimming':
        if (_intensity == 'low') met = 6.0;
        else if (_intensity == 'medium') met = 8.0;
        else if (_intensity == 'high') met = 10.0;
        break;
      case 'gym':
      case 'gym (weight training)':
        if (_intensity == 'low') met = 3.0;
        else if (_intensity == 'medium') met = 6.0;
        else if (_intensity == 'high') met = 8.0;
        break;
      default:
        return;
    }
    final caloriesPerMinute = (met * 3.5 * _userWeight!) / 200.0;
    final calories = (caloriesPerMinute * durationMin).round();
    setState(() {
      _calories = calories.toString();
    });
  }

  void _onTypeChanged(String? v) {
    setState(() {
      _type = v ?? '';
      if (_type != 'Other') _customType = '';
      _caloriesManuallyEdited = false;
    });
    _maybeAutoCalculateCalories();
  }

  void _onCustomTypeChanged(String v) {
    setState(() {
      _customType = v;
      _caloriesManuallyEdited = false;
    });
    _maybeAutoCalculateCalories();
  }

  void _onDurationChanged(String v) {
    setState(() {
      _duration = v;
      _caloriesManuallyEdited = false;
    });
    _maybeAutoCalculateCalories();
  }

  void _onIntensityChanged(String? v) {
    setState(() {
      _intensity = v ?? 'medium';
      _caloriesManuallyEdited = false;
    });
    _maybeAutoCalculateCalories();
  }

  void _onCaloriesChanged(String v) {
    setState(() {
      _calories = v;
      _caloriesManuallyEdited = true;
    });
  }

  Future<void> _fetchWorkouts() async {
    setState(() { _loading = true; });
    try {
      final params = <String, String>{};
      if (_startDate != null) params['start'] = DateFormat('yyyy-MM-dd').format(_startDate!);
      if (_endDate != null) {
        final inclusiveEnd = _endDate!.add(const Duration(days: 1));
        params['end'] = DateFormat('yyyy-MM-dd').format(inclusiveEnd);
      }
      if (_filterCategory.isNotEmpty) params['category'] = _filterCategory;
      if (_filterType.isNotEmpty) params['type'] = _filterType;
      final workouts = await api.fetchWorkoutsWithParams(params);
      setState(() { _workouts = workouts; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Failed to load workouts'; _loading = false; });
    }
  }

  void _openCreateForm() {
    setState(() {
      _showForm = true;
      _editing = false;
      _editingWorkout = null;
      _type = '';
      _customType = '';
      _duration = '';
      _intensity = 'medium';
      _calories = '';
      _location = '';
      _caloriesManuallyEdited = false;
      _category = '';
      _customCategory = '';
    });
  }

  void _openEditForm(Workout w) {
    setState(() {
      _showForm = true;
      _editing = true;
      _editingWorkout = w;
      _type = w.type;
      _customType = '';
      _duration = w.duration.toString();
      _intensity = w.intensity;
      _calories = w.calories.toString();
      _location = w.location;
      _category = w.category;
      _customCategory = '';
      _caloriesManuallyEdited = false;
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _formLoading = true; });
    final workout = Workout(
      id: _editing ? _editingWorkout!.id : 0,
      userId: 0,
      type: _type == 'Other' ? _customType : _type,
      duration: int.tryParse(_duration) ?? 0,
      intensity: _intensity,
      calories: int.tryParse(_calories) ?? 0,
      location: _location,
      category: _category == 'Other' ? _customCategory : _category,
      createdAt: _editing ? _editingWorkout!.createdAt : null,
    );
    if (_editing && _editingWorkout != null) {
      final updated = await api.updateWorkout(workout);
      setState(() { _formLoading = false; _showForm = false; });
      if (updated != null) {
        _fetchWorkouts();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Workout updated')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update workout')));
      }
    } else {
      final created = await api.createWorkout(workout);
      setState(() { _formLoading = false; _showForm = false; });
      if (created != null) {
        _fetchWorkouts();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Workout added')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to add workout')));
      }
    }
  }

  Future<void> _deleteWorkout(int id) async {
    final success = await api.deleteWorkout(id);
    if (success) {
      _fetchWorkouts();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Workout deleted')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete workout')));
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() { _startDate = picked; });
      _fetchWorkouts();
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() { _endDate = picked; });
      _fetchWorkouts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Workouts & Activity History', style: Theme.of(context).textTheme.headlineMedium),
              IconButton(
                icon: Icon(_showForm ? Icons.close : Icons.add),
                onPressed: () => setState(() => _showForm ? _showForm = false : _openCreateForm()),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _fetchWorkouts,
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _pickStartDate,
                  child: Text(_startDate != null ? 'From: ' + DateFormat('yyyy-MM-dd').format(_startDate!) : 'From'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _pickEndDate,
                  child: Text(_endDate != null ? 'To: ' + DateFormat('yyyy-MM-dd').format(_endDate!) : 'To'),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _filterCategory,
                  items: _filterCategoryOptions.map((cat) => DropdownMenuItem(
                    value: cat,
                    child: Text(cat.isEmpty ? 'All Categories' : cat),
                  )).toList(),
                  onChanged: (v) { setState(() { _filterCategory = v ?? ''; }); _fetchWorkouts(); },
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _filterType,
                  items: _filterTypeOptions.map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(type.isEmpty ? 'All Types' : type),
                  )).toList(),
                  onChanged: (v) { setState(() { _filterType = v ?? ''; }); _fetchWorkouts(); },
                  decoration: const InputDecoration(labelText: 'Type'),
                ),
              ),
            ],
          ),
          if (_showForm)
            Form(
              key: _formKey,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _type.isNotEmpty ? _type : null,
                    items: _typeOptions.map((type) => DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    )).toList(),
                    onChanged: _onTypeChanged,
                    decoration: const InputDecoration(labelText: 'Type'),
                    validator: (v) => v == null || v.isEmpty ? 'Select workout type' : null,
                  ),
                  if (_type == 'Other')
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Custom Type'),
                      initialValue: _customType,
                      onChanged: _onCustomTypeChanged,
                      validator: (v) => _type == 'Other' && (v == null || v.isEmpty) ? 'Enter custom type' : null,
                    ),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Duration (minutes)'),
                    initialValue: _duration,
                    keyboardType: TextInputType.number,
                    onChanged: _onDurationChanged,
                    validator: (v) => v == null || v.isEmpty ? 'Enter duration' : null,
                  ),
                  DropdownButtonFormField<String>(
                    value: _intensity,
                    items: _intensityOptions.map((level) => DropdownMenuItem(
                      value: level,
                      child: Text(level[0].toUpperCase() + level.substring(1)),
                    )).toList(),
                    onChanged: _onIntensityChanged,
                    decoration: const InputDecoration(labelText: 'Intensity'),
                  ),
                  (_type == 'Other')
                    ? TextFormField(
                        decoration: const InputDecoration(labelText: 'Calories burned'),
                        initialValue: _calories,
                        keyboardType: TextInputType.number,
                        onChanged: _onCaloriesChanged,
                        validator: (v) => v == null || v.isEmpty ? 'Enter calories' : null,
                      )
                    : TextFormField(
                        decoration: const InputDecoration(labelText: 'Calories burned (auto)'),
                        initialValue: _calories,
                        enabled: false,
                      ),
                  DropdownButtonFormField<String>(
                    value: _category.isNotEmpty ? _category : null,
                    items: _categoryOptions.map((cat) => DropdownMenuItem(
                      value: cat,
                      child: Text(cat),
                    )).toList(),
                    onChanged: (v) => setState(() { _category = v ?? ''; if (_category != 'Other') _customCategory = ''; }),
                    decoration: const InputDecoration(labelText: 'Category'),
                    validator: (v) => v == null || v.isEmpty ? 'Select category' : null,
                  ),
                  if (_category == 'Other')
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Custom Category'),
                      initialValue: _customCategory,
                      onChanged: (v) => _customCategory = v,
                      validator: (v) => _category == 'Other' && (v == null || v.isEmpty) ? 'Enter custom category' : null,
                    ),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Location'),
                    initialValue: _location,
                    onChanged: (v) => _location = v,
                    validator: (v) => v == null || v.isEmpty ? 'Enter location' : null,
                  ),
                  const SizedBox(height: 8),
                  _formLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _submitForm,
                          child: Text(_editing ? 'Update Workout' : 'Add Workout'),
                        ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          if (_loading)
            const CircularProgressIndicator()
          else if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red))
          else if (_workouts.isEmpty)
            const Text('No workouts found.')
          else
            Expanded(
              child: ListView.builder(
                itemCount: _workouts.length,
                itemBuilder: (context, index) {
                  final w = _workouts[index];
                  return ListTile(
                    leading: const Icon(Icons.fitness_center),
                    title: Text(w.type),
                    subtitle: Text('Category: ${w.category}, Duration: ${w.duration} min, Intensity: ${w.intensity}, Calories: ${w.calories}, Location: ${w.location}, Time: ${w.createdAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(w.createdAt!) : ''}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _openEditForm(w),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteWorkout(w.id),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class WaterScreen extends StatefulWidget {
  WaterScreen({super.key});

  @override
  State<WaterScreen> createState() => _WaterScreenState();
}

class _WaterScreenState extends State<WaterScreen> {
  final ApiService api = ApiService();
  List<WaterIntake> _waterIntakes = [];
  bool _loading = false;
  String? _error;
  bool _showForm = false;
  bool _formLoading = false;
  bool _editing = false;
  WaterIntake? _editingWaterIntake;
  final _formKey = GlobalKey<FormState>();
  String _amount = '';

  int _waterGoal = 2000;
  bool _goalLoading = false;
  bool _editingGoal = false;
  String _goalInput = '';

  List<Streak> _streaks = [];
  bool _streaksLoading = false;

  Map<String, dynamic>? _streakRanking;
  bool _rankingLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchWaterIntakes();
    _fetchWaterGoal();
    _fetchStreaks();
    _fetchStreakRanking();
  }

  Future<void> _fetchWaterGoal() async {
    setState(() { _goalLoading = true; });
    final settings = await api.fetchSettings();
    setState(() {
      _waterGoal = settings?.waterGoal ?? 2000;
      _goalInput = _waterGoal.toString();
      _goalLoading = false;
    });
  }

  Future<void> _fetchStreaks() async {
    setState(() { _streaksLoading = true; });
    try {
      final streaks = await api.fetchStreaks();
      setState(() { _streaks = streaks; _streaksLoading = false; });
    } catch (e) {
      setState(() { _streaksLoading = false; });
    }
  }

  Future<void> _fetchStreakRanking() async {
    setState(() { _rankingLoading = true; });
    try {
      final ranking = await api.fetchStreakRanking('water');
      setState(() { _streakRanking = ranking; _rankingLoading = false; });
    } catch (e) {
      setState(() { _rankingLoading = false; });
    }
  }

  Future<void> _updateWaterGoal() async {
    setState(() { _goalLoading = true; });
    final settings = await api.fetchSettings();
    if (settings != null) {
      final updated = await api.updateSettings(Settings(
        userId: settings.userId,
        notificationsEnabled: settings.notificationsEnabled,
        theme: settings.theme,
        waterGoal: int.tryParse(_goalInput) ?? _waterGoal,
        caloriesGoal: settings.caloriesGoal,
        stepsGoal: settings.stepsGoal, // add this line
      ));
      setState(() {
        _editingGoal = false;
        _waterGoal = updated?.waterGoal ?? _waterGoal;
        _goalLoading = false;
      });
      _fetchStreaks(); // Refresh streaks after goal update
    } else {
      setState(() { _goalLoading = false; });
    }
  }

  int get _todayIntake {
    final today = DateTime.now();
    return _waterIntakes.fold(0, (sum, w) => sum + w.amount);
  }

  Streak? get _waterStreak {
    return _streaks.where((s) => s.type == 'water').firstOrNull;
  }

  // Check if we should refresh streaks based on current intake
  bool get _shouldRefreshStreaks {
    return _todayIntake >= _waterGoal * 0.9; // When at 90% of goal
  }

  Future<void> _fetchWaterIntakes() async {
    setState(() { _loading = true; });
    try {
      final waterIntakes = await api.fetchWaterIntakes();
      setState(() { _waterIntakes = waterIntakes; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Failed to load water intakes'; _loading = false; });
    }
  }

  void _openCreateForm() {
    setState(() {
      _showForm = true;
      _editing = false;
      _editingWaterIntake = null;
      _amount = '';
    });
  }

  void _openEditForm(WaterIntake waterIntake) {
    setState(() {
      _showForm = true;
      _editing = true;
      _editingWaterIntake = waterIntake;
      _amount = waterIntake.amount.toString();
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _formLoading = true; });
    if (_editing && _editingWaterIntake != null) {
      final updated = await api.updateWaterIntake(WaterIntake(
        id: _editingWaterIntake!.id,
        userId: _editingWaterIntake!.userId,
        amount: int.tryParse(_amount) ?? 0,
      ));
      setState(() { _formLoading = false; _showForm = false; });
      if (updated != null) {
        _fetchWaterIntakes();
        _fetchStreaks(); // Refresh streaks after update
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Water intake updated')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update water intake')));
      }
    } else {
      final created = await api.createWaterIntake(WaterIntake(
        id: 0,
        userId: 0,
        amount: int.tryParse(_amount) ?? 0,
      ));
      setState(() { _formLoading = false; _showForm = false; });
      if (created != null) {
        _fetchWaterIntakes();
        // Refresh streaks if we're approaching or reaching the goal
        if (_shouldRefreshStreaks) {
          _fetchStreaks();
          _fetchStreakRanking();
        }
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Water intake added')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to add water intake')));
      }
    }
  }

  Future<void> _deleteWaterIntake(int id) async {
    final success = await api.deleteWaterIntake(id);
    if (success) {
      _fetchWaterIntakes();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Water intake deleted')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete water intake')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Water Intake', style: Theme.of(context).textTheme.headlineMedium),
              IconButton(
                icon: Icon(_showForm ? Icons.close : Icons.add),
                onPressed: () => setState(() => _showForm ? _showForm = false : _openCreateForm()),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_goalLoading)
            const CircularProgressIndicator()
          else
            Row(
              children: [
                Text('Daily Goal: ', style: Theme.of(context).textTheme.bodyLarge),
                if (_editingGoal)
                  SizedBox(
                    width: 80,
                    child: TextFormField(
                      initialValue: _goalInput,
                      keyboardType: TextInputType.number,
                      onChanged: (v) => _goalInput = v,
                    ),
                  )
                else
                  Text('$_waterGoal ml', style: Theme.of(context).textTheme.bodyLarge),
                IconButton(
                  icon: Icon(_editingGoal ? Icons.check : Icons.edit),
                  onPressed: () {
                    if (_editingGoal) {
                      _updateWaterGoal();
                    } else {
                      setState(() { _editingGoal = true; });
                    }
                  },
                ),
              ],
            ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (_todayIntake / (_waterGoal > 0 ? _waterGoal : 1)).clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
          const SizedBox(height: 4),
          Text('Today: $_todayIntake / $_waterGoal ml'),

          // Streak Information
          const SizedBox(height: 16),
          if (_streaksLoading)
            const CircularProgressIndicator()
          else if (_waterStreak != null)
            Card(
              color: (_todayIntake >= _waterGoal) ? Colors.blue.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          (_todayIntake >= _waterGoal) ? Icons.local_fire_department : Icons.trending_up,
                          color: (_todayIntake >= _waterGoal) ? Colors.orange : Colors.grey,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Water Streak',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current: ${_waterStreak!.current} days',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: (_todayIntake >= _waterGoal) ? Colors.blue : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Longest: ${_waterStreak!.longest} days',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            if (_streakRanking != null)
                              Text(
                                'Ranking: #${_streakRanking!['rating']} among friends',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (_todayIntake >= _waterGoal)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Goal Achieved!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            if (_rankingLoading)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh Streaks'),
            onPressed: () {
              _fetchStreaks();
              _fetchStreakRanking();
            },
          ),

          if (_showForm)
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Amount (ml)'),
                    initialValue: _amount,
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _amount = v,
                    validator: (v) => v == null || v.isEmpty ? 'Enter amount' : null,
                  ),
                  const SizedBox(height: 8),
                  _formLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _submitForm,
                          child: Text(_editing ? 'Update Water Intake' : 'Add Water Intake'),
                        ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          if (_loading)
            const CircularProgressIndicator()
          else if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red))
          else if (_waterIntakes.isEmpty)
            const Text('No water intake records found.')
          else
            Expanded(
              child: ListView.builder(
                itemCount: _waterIntakes.length,
                itemBuilder: (context, index) {
                  final water = _waterIntakes[index];
                  return ListTile(
                    leading: const Icon(Icons.local_drink),
                    title: Text('Amount: ${water.amount} ml'),
                    subtitle: Text('User ID: ${water.userId}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _openEditForm(water),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteWaterIntake(water.id),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class DietScreen extends StatefulWidget {
  DietScreen({super.key});

  @override
  State<DietScreen> createState() => _DietScreenState();
}

class _DietScreenState extends State<DietScreen> {
  final ApiService api = ApiService();
  List<DietEntry> _dietEntries = [];
  bool _loading = false;
  String? _error;
  bool _showForm = false;
  bool _formLoading = false;
  bool _editing = false;
  DietEntry? _editingDietEntry;
  final _formKey = GlobalKey<FormState>();
  String _meal = '';
  String _food = '';
  String _calories = '';

  int _caloriesGoal = 2000;
  bool _goalLoading = false;
  bool _editingGoal = false;
  String _goalInput = '';

  List<Streak> _streaks = [];
  bool _streaksLoading = false;

  Map<String, dynamic>? _streakRanking;
  bool _rankingLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchDietEntries();
    _fetchCaloriesGoal();
    _fetchStreaks();
    _fetchStreakRanking();
  }

  Future<void> _fetchCaloriesGoal() async {
    setState(() { _goalLoading = true; });
    final settings = await api.fetchSettings();
    setState(() {
      _caloriesGoal = settings?.caloriesGoal ?? 2000;
      _goalInput = _caloriesGoal.toString();
      _goalLoading = false;
    });
  }

  Future<void> _fetchStreaks() async {
    setState(() { _streaksLoading = true; });
    try {
      final streaks = await api.fetchStreaks();
      setState(() { _streaks = streaks; _streaksLoading = false; });
    } catch (e) {
      setState(() { _streaksLoading = false; });
    }
  }

  Future<void> _fetchStreakRanking() async {
    setState(() { _rankingLoading = true; });
    try {
      final ranking = await api.fetchStreakRanking('diet');
      setState(() { _streakRanking = ranking; _rankingLoading = false; });
    } catch (e) {
      setState(() { _rankingLoading = false; });
    }
  }

  Future<void> _updateCaloriesGoal() async {
    setState(() { _goalLoading = true; });
    final settings = await api.fetchSettings();
    if (settings != null) {
      final updated = await api.updateSettings(Settings(
        userId: settings.userId,
        notificationsEnabled: settings.notificationsEnabled,
        theme: settings.theme,
        waterGoal: settings.waterGoal,
        caloriesGoal: int.tryParse(_goalInput) ?? _caloriesGoal,
        stepsGoal: settings.stepsGoal, // add this line
      ));
      setState(() {
        _editingGoal = false;
        _caloriesGoal = updated?.caloriesGoal ?? _caloriesGoal;
        _goalLoading = false;
      });
      _fetchStreaks(); // Refresh streaks after goal update
    } else {
      setState(() { _goalLoading = false; });
    }
  }

  int get _todayCalories {
    final today = DateTime.now();
    return _dietEntries.fold(0, (sum, d) => sum + d.calories);
  }

  Streak? get _dietStreak {
    return _streaks.where((s) => s.type == 'diet').firstOrNull;
  }

  // Check if we should refresh streaks based on current calories
  bool get _shouldRefreshStreaks {
    return _todayCalories >= _caloriesGoal * 0.9; // When at 90% of goal
  }

  Future<void> _fetchDietEntries() async {
    setState(() { _loading = true; });
    try {
      final dietEntries = await api.fetchDietEntries();
      setState(() { _dietEntries = dietEntries; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Failed to load diet entries'; _loading = false; });
    }
  }

  void _openCreateForm() {
    setState(() {
      _showForm = true;
      _editing = false;
      _editingDietEntry = null;
      _meal = '';
      _food = '';
      _calories = '';
    });
  }

  void _openEditForm(DietEntry dietEntry) {
    setState(() {
      _showForm = true;
      _editing = true;
      _editingDietEntry = dietEntry;
      _meal = dietEntry.meal;
      _food = dietEntry.food;
      _calories = dietEntry.calories.toString();
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _formLoading = true; });
    if (_editing && _editingDietEntry != null) {
      final updated = await api.updateDietEntry(DietEntry(
        id: _editingDietEntry!.id,
        userId: _editingDietEntry!.userId,
        meal: _meal,
        food: _food,
        calories: int.tryParse(_calories) ?? 0,
      ));
      setState(() { _formLoading = false; _showForm = false; });
      if (updated != null) {
        _fetchDietEntries();
        _fetchStreaks(); // Refresh streaks after update
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Diet entry updated')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update diet entry')));
      }
    } else {
      final created = await api.createDietEntry(DietEntry(
        id: 0,
        userId: 0,
        meal: _meal,
        food: _food,
        calories: int.tryParse(_calories) ?? 0,
      ));
      setState(() { _formLoading = false; _showForm = false; });
      if (created != null) {
        _fetchDietEntries();
        // Refresh streaks if we're approaching or reaching the goal
        if (_shouldRefreshStreaks) {
          _fetchStreaks();
          _fetchStreakRanking();
        }
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Diet entry added')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to add diet entry')));
      }
    }
  }

  Future<void> _deleteDietEntry(int id) async {
    final success = await api.deleteDietEntry(id);
    if (success) {
      _fetchDietEntries();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Diet entry deleted')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete diet entry')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Diet Entries', style: Theme.of(context).textTheme.headlineMedium),
              IconButton(
                icon: Icon(_showForm ? Icons.close : Icons.add),
                onPressed: () => setState(() => _showForm ? _showForm = false : _openCreateForm()),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_goalLoading)
            const CircularProgressIndicator()
          else
            Row(
              children: [
                Text('Daily Calories Goal: ', style: Theme.of(context).textTheme.bodyLarge),
                if (_editingGoal)
                  SizedBox(
                    width: 80,
                    child: TextFormField(
                      initialValue: _goalInput,
                      keyboardType: TextInputType.number,
                      onChanged: (v) => _goalInput = v,
                    ),
                  )
                else
                  Text('$_caloriesGoal kcal', style: Theme.of(context).textTheme.bodyLarge),
                IconButton(
                  icon: Icon(_editingGoal ? Icons.check : Icons.edit),
                  onPressed: () {
                    if (_editingGoal) {
                      _updateCaloriesGoal();
                    } else {
                      setState(() { _editingGoal = true; });
                    }
                  },
                ),
              ],
            ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (_todayCalories / (_caloriesGoal > 0 ? _caloriesGoal : 1)).clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
          ),
          const SizedBox(height: 4),
          Text('Today: $_todayCalories / $_caloriesGoal kcal'),

          // Streak Information
          const SizedBox(height: 16),
          if (_streaksLoading)
            const CircularProgressIndicator()
          else if (_dietStreak != null)
            Card(
              color: (_todayCalories >= _caloriesGoal) ? Colors.orange.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          (_todayCalories >= _caloriesGoal) ? Icons.local_fire_department : Icons.trending_up,
                          color: (_todayCalories >= _caloriesGoal) ? Colors.orange : Colors.grey,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Diet Streak',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current: ${_dietStreak!.current} days',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: (_todayCalories >= _caloriesGoal) ? Colors.orange : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Longest: ${_dietStreak!.longest} days',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            if (_streakRanking != null)
                              Text(
                                'Ranking: #${_streakRanking!['rating']} among friends',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (_todayCalories >= _caloriesGoal)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Goal Achieved!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            if (_rankingLoading)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh Streaks'),
            onPressed: () {
              _fetchStreaks();
              _fetchStreakRanking();
            },
          ),

          if (_showForm)
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Meal'),
                    initialValue: _meal,
                    onChanged: (v) => _meal = v,
                    validator: (v) => v == null || v.isEmpty ? 'Enter meal' : null,
                  ),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Food'),
                    initialValue: _food,
                    onChanged: (v) => _food = v,
                    validator: (v) => v == null || v.isEmpty ? 'Enter food' : null,
                  ),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Calories'),
                    initialValue: _calories,
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _calories = v,
                    validator: (v) => v == null || v.isEmpty ? 'Enter calories' : null,
                  ),
                  const SizedBox(height: 8),
                  _formLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _submitForm,
                          child: Text(_editing ? 'Update Diet Entry' : 'Add Diet Entry'),
                        ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          if (_loading)
            const CircularProgressIndicator()
          else if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red))
          else if (_dietEntries.isEmpty)
            const Text('No diet entries found.')
          else
            Expanded(
              child: ListView.builder(
                itemCount: _dietEntries.length,
                itemBuilder: (context, index) {
                  final diet = _dietEntries[index];
                  return ListTile(
                    leading: const Icon(Icons.restaurant),
                    title: Text('Meal: ${diet.meal}'),
                    subtitle: Text('Food: ${diet.food}, Calories: ${diet.calories}, User ID: ${diet.userId}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _openEditForm(diet),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteDietEntry(diet.id),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class PeriodsScreen extends StatefulWidget {
  PeriodsScreen({super.key});

  @override
  State<PeriodsScreen> createState() => _PeriodsScreenState();
}

class _PeriodsScreenState extends State<PeriodsScreen> {
  final ApiService api = ApiService();
  List<Period> _periods = [];
  bool _loading = false;
  String? _error;
  bool _showForm = false;
  bool _formLoading = false;
  bool _editing = false;
  Period? _editingPeriod;
  final _formKey = GlobalKey<FormState>();
  String _start = '';
  String _end = '';

  @override
  void initState() {
    super.initState();
    _fetchPeriods();
  }

  Future<void> _fetchPeriods() async {
    setState(() { _loading = true; });
    try {
      final periods = await api.fetchPeriods();
      setState(() { _periods = periods; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Failed to load periods'; _loading = false; });
    }
  }

  void _openCreateForm() {
    setState(() {
      _showForm = true;
      _editing = false;
      _editingPeriod = null;
      _start = '';
      _end = '';
    });
  }

  void _openEditForm(Period period) {
    setState(() {
      _showForm = true;
      _editing = true;
      _editingPeriod = period;
      _start = period.start;
      _end = period.end;
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _formLoading = true; });
    if (_editing && _editingPeriod != null) {
      final updated = await api.updatePeriod(Period(
        id: _editingPeriod!.id,
        userId: _editingPeriod!.userId,
        start: _start,
        end: _end,
      ));
      setState(() { _formLoading = false; _showForm = false; });
      if (updated != null) {
        _fetchPeriods();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Period updated')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update period')));
      }
    } else {
      final created = await api.createPeriod(Period(
        id: 0,
        userId: 0,
        start: _start,
        end: _end,
      ));
      setState(() { _formLoading = false; _showForm = false; });
      if (created != null) {
        _fetchPeriods();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Period added')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to add period')));
      }
    }
  }

  Future<void> _deletePeriod(int id) async {
    final success = await api.deletePeriod(id);
    if (success) {
      _fetchPeriods();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Period deleted')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete period')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Periods', style: Theme.of(context).textTheme.headlineMedium),
              IconButton(
                icon: Icon(_showForm ? Icons.close : Icons.add),
                onPressed: () => setState(() => _showForm ? _showForm = false : _openCreateForm()),
              ),
            ],
          ),
          if (_showForm)
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Start Date (YYYY-MM-DD)'),
                    initialValue: _start,
                    onChanged: (v) => _start = v,
                    validator: (v) => v == null || v.isEmpty ? 'Enter start date' : null,
                  ),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'End Date (YYYY-MM-DD)'),
                    initialValue: _end,
                    onChanged: (v) => _end = v,
                    validator: (v) => v == null || v.isEmpty ? 'Enter end date' : null,
                  ),
                  const SizedBox(height: 8),
                  _formLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _submitForm,
                          child: Text(_editing ? 'Update Period' : 'Add Period'),
                        ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          if (_loading)
            const CircularProgressIndicator()
          else if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red))
          else if (_periods.isEmpty)
            const Text('No periods found.')
          else
            Expanded(
              child: ListView.builder(
                itemCount: _periods.length,
                itemBuilder: (context, index) {
                  final period = _periods[index];
                  return ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: Text('Start: ${period.start}'),
                    subtitle: Text('End: ${period.end}, User ID: ${period.userId}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _openEditForm(period),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deletePeriod(period.id),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class AwardsScreen extends StatelessWidget {
  final ApiService api = ApiService();

  AwardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Award>>(
      future: api.fetchAwards(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        } else if (snapshot.hasError) {
          return Text('Error: \\${snapshot.error}');
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text('No awards found.');
        } else {
          final awards = snapshot.data!;
          return ListView.builder(
            itemCount: awards.length,
            itemBuilder: (context, index) {
              final award = awards[index];
              return ListTile(
                leading: const Icon(Icons.emoji_events),
                title: Text(award.title),
                subtitle: Text('Desc: ${award.desc}, User ID: ${award.userId}'),
              );
            },
          );
        }
      },
    );
  }
}



class HealthRecordsScreen extends StatefulWidget {
  HealthRecordsScreen({super.key});

  @override
  State<HealthRecordsScreen> createState() => _HealthRecordsScreenState();
}

class _HealthRecordsScreenState extends State<HealthRecordsScreen> {
  final ApiService api = ApiService();
  List<HealthRecord> _healthRecords = [];
  bool _loading = false;
  String? _error;
  bool _showForm = false;
  bool _formLoading = false;
  bool _editing = false;
  HealthRecord? _editingHealthRecord;
  final _formKey = GlobalKey<FormState>();
  String _type = '';
  String _value = '';
  String _date = '';

  @override
  void initState() {
    super.initState();
    _fetchHealthRecords();
  }

  Future<void> _fetchHealthRecords() async {
    setState(() { _loading = true; });
    try {
      final healthRecords = await api.fetchHealthRecords();
      setState(() { _healthRecords = healthRecords; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Failed to load health records'; _loading = false; });
    }
  }

  void _openCreateForm() {
    setState(() {
      _showForm = true;
      _editing = false;
      _editingHealthRecord = null;
      _type = '';
      _value = '';
      _date = '';
    });
  }

  void _openEditForm(HealthRecord record) {
    setState(() {
      _showForm = true;
      _editing = true;
      _editingHealthRecord = record;
      _type = record.type;
      _value = record.value;
      _date = record.date;
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _formLoading = true; });
    if (_editing && _editingHealthRecord != null) {
      final updated = await api.updateHealthRecord(HealthRecord(
        id: _editingHealthRecord!.id,
        userId: _editingHealthRecord!.userId,
        type: _type,
        value: _value,
        date: _date,
      ));
      setState(() { _formLoading = false; _showForm = false; });
      if (updated != null) {
        _fetchHealthRecords();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Health record updated')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update health record')));
      }
    } else {
      final created = await api.createHealthRecord(HealthRecord(
        id: 0,
        userId: 0,
        type: _type,
        value: _value,
        date: _date,
      ));
      setState(() { _formLoading = false; _showForm = false; });
      if (created != null) {
        _fetchHealthRecords();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Health record added')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to add health record')));
      }
    }
  }

  Future<void> _deleteHealthRecord(int id) async {
    final success = await api.deleteHealthRecord(id);
    if (success) {
      _fetchHealthRecords();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Health record deleted')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete health record')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Health Records', style: Theme.of(context).textTheme.headlineMedium),
              IconButton(
                icon: Icon(_showForm ? Icons.close : Icons.add),
                onPressed: () => setState(() => _showForm ? _showForm = false : _openCreateForm()),
              ),
            ],
          ),
          if (_showForm)
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Type'),
                    initialValue: _type,
                    onChanged: (v) => _type = v,
                    validator: (v) => v == null || v.isEmpty ? 'Enter type' : null,
                  ),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Value'),
                    initialValue: _value,
                    onChanged: (v) => _value = v,
                    validator: (v) => v == null || v.isEmpty ? 'Enter value' : null,
                  ),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)'),
                    initialValue: _date,
                    onChanged: (v) => _date = v,
                    validator: (v) => v == null || v.isEmpty ? 'Enter date' : null,
                  ),
                  const SizedBox(height: 8),
                  _formLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _submitForm,
                          child: Text(_editing ? 'Update Health Record' : 'Add Health Record'),
                        ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          if (_loading)
            const CircularProgressIndicator()
          else if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red))
          else if (_healthRecords.isEmpty)
            const Text('No health records found.')
          else
            Expanded(
              child: ListView.builder(
                itemCount: _healthRecords.length,
                itemBuilder: (context, index) {
                  final record = _healthRecords[index];
                  return ListTile(
                    leading: const Icon(Icons.health_and_safety),
                    title: Text('Type: ${record.type}'),
                    subtitle: Text('Value: ${record.value}, Date: ${record.date}, User ID: ${record.userId}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _openEditForm(record),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteHealthRecord(record.id),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService api = ApiService();
  final _formKey = GlobalKey<FormState>();
  String? _name;
  String? _email;
  double? _weight;
  int? _age;
  String? _sex;
  double? _height;
  String? _error;
  bool _loading = false;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() { _loading = true; });
    final user = await api.getMe();
    setState(() {
      _loading = false;
      if (user != null) {
        _name = user.name;
        _email = user.email;
        _weight = user.weight;
        _age = user.age;
        _sex = user.sex;
        _height = user.height;
      } else {
        _error = 'Failed to load profile';
      }
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    final user = await api.updateMe(_name!, _email!, _weight ?? 70, _age ?? 18, _sex ?? 'other', _height ?? 170);
    setState(() { _loading = false; });
    if (user != null) {
      setState(() { _editing = false; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
    } else {
      setState(() { _error = 'Failed to update profile'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            Text('Profile', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),
            TextFormField(
              initialValue: _name,
              enabled: _editing,
              decoration: const InputDecoration(labelText: 'Name'),
              onChanged: (v) => _name = v,
              validator: (v) => v == null || v.isEmpty ? 'Enter name' : null,
            ),
            TextFormField(
              initialValue: _email,
              enabled: _editing,
              decoration: const InputDecoration(labelText: 'Email'),
              onChanged: (v) => _email = v,
              validator: (v) => v == null || v.isEmpty ? 'Enter email' : null,
            ),
            TextFormField(
              initialValue: _weight?.toString() ?? '',
              decoration: const InputDecoration(labelText: 'Weight (kg)'),
              keyboardType: TextInputType.number,
              onChanged: (v) => _weight = double.tryParse(v),
            ),
            TextFormField(
              initialValue: _age?.toString() ?? '',
              decoration: const InputDecoration(labelText: 'Age'),
              keyboardType: TextInputType.number,
              onChanged: (v) => _age = int.tryParse(v),
            ),
            DropdownButtonFormField<String>(
              value: _sex,
              items: const [
                DropdownMenuItem(value: 'male', child: Text('Male')),
                DropdownMenuItem(value: 'female', child: Text('Female')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (v) => setState(() => _sex = v),
              decoration: const InputDecoration(labelText: 'Sex'),
            ),
            TextFormField(
              initialValue: _height?.toString() ?? '',
              decoration: const InputDecoration(labelText: 'Height (cm)'),
              keyboardType: TextInputType.number,
              onChanged: (v) => _height = double.tryParse(v),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            _editing
                ? ElevatedButton(
                    onPressed: _saveProfile,
                    child: const Text('Save'),
                  )
                : ElevatedButton(
                    onPressed: () => setState(() => _editing = true),
                    child: const Text('Edit'),
                  ),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ApiService api = ApiService();
  bool? _notificationsEnabled;
  String? _theme;
  bool _loading = false;
  String? _error;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    setState(() { _loading = true; });
    final settings = await api.getSettings();
    setState(() {
      _loading = false;
      if (settings != null) {
        _notificationsEnabled = settings.notificationsEnabled;
        _theme = settings.theme;
      } else {
        _error = 'Failed to load settings';
      }
    });
  }

  Future<void> _saveSettings() async {
    setState(() { _loading = true; _error = null; });
    final settings = Settings(
      userId: 0, // Placeholder, replace with actual user ID
      notificationsEnabled: _notificationsEnabled ?? true,
      theme: _theme ?? 'light',
      waterGoal: 2000, // Placeholder, replace with actual water goal
      caloriesGoal: 2000, // Placeholder, replace with actual calories goal
      stepsGoal: 10000, // add this line
    );
    final updated = await api.updateSettings(settings);
    setState(() { _loading = false; });
    if (updated != null) {
      setState(() { _editing = false; });
      MyApp.of(context)?.updateTheme(updated.theme); // Notify MyApp
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings updated')));
    } else {
      setState(() { _error = 'Failed to update settings'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),
          SwitchListTile(
            title: const Text('Enable Notifications'),
            value: _notificationsEnabled ?? true,
            onChanged: _editing ? (v) => setState(() => _notificationsEnabled = v) : null,
          ),
          DropdownButtonFormField<String>(
            value: _theme ?? 'light',
            decoration: const InputDecoration(labelText: 'Theme'),
            items: const [
              DropdownMenuItem(value: 'light', child: Text('Light')),
              DropdownMenuItem(value: 'dark', child: Text('Dark')),
            ],
            onChanged: _editing ? (v) => setState(() => _theme = v) : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 16),
          _editing
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _saveSettings,
                      child: const Text('Save'),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton(
                      onPressed: () => setState(() { _editing = false; }),
                      child: const Text('Cancel'),
                    ),
                  ],
                )
              : ElevatedButton(
                  onPressed: () => setState(() { _editing = true; }),
                  child: const Text('Edit'),
                ),
        ],
      ),
    );
  }
}

class RemindersScreen extends StatefulWidget {
  RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final ApiService api = ApiService();
  List<Reminder> _reminders = [];
  bool _loading = false;
  String? _error;
  bool _showForm = false;
  bool _formLoading = false;
  bool _editing = false;
  Reminder? _editingReminder;
  final _formKey = GlobalKey<FormState>();
  String _time = '';
  String _message = '';
  String _type = '';

  @override
  void initState() {
    super.initState();
    _fetchReminders();
  }

  Future<void> _fetchReminders() async {
    setState(() { _loading = true; });
    try {
      final reminders = await api.fetchReminders();
      setState(() { _reminders = reminders; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Failed to load reminders'; _loading = false; });
    }
  }

  void _openCreateForm() {
    setState(() {
      _showForm = true;
      _editing = false;
      _editingReminder = null;
      _time = '';
      _message = '';
      _type = '';
    });
  }

  void _openEditForm(Reminder reminder) {
    setState(() {
      _showForm = true;
      _editing = true;
      _editingReminder = reminder;
      _time = reminder.time;
      _message = reminder.message;
      _type = reminder.type;
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _formLoading = true; });
    if (_editing && _editingReminder != null) {
      final updated = await api.updateReminder(Reminder(
        id: _editingReminder!.id,
        time: _time,
        message: _message,
        type: _type,
      ));
      setState(() { _formLoading = false; _showForm = false; });
      if (updated != null) {
        _fetchReminders();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reminder updated')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update reminder')));
      }
    } else {
      final created = await api.createReminder(Reminder(
        id: 0,
        time: _time,
        message: _message,
        type: _type,
      ));
      setState(() { _formLoading = false; _showForm = false; });
      if (created != null) {
        _fetchReminders();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reminder added')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to add reminder')));
      }
    }
  }

  Future<void> _deleteReminder(int id) async {
    final success = await api.deleteReminder(id);
    if (success) {
      _fetchReminders();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reminder deleted')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete reminder')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Reminders', style: Theme.of(context).textTheme.headlineMedium),
              IconButton(
                icon: Icon(_showForm ? Icons.close : Icons.add),
                onPressed: () => setState(() => _showForm ? _showForm = false : _openCreateForm()),
              ),
            ],
          ),
          if (_showForm)
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Time'),
                    initialValue: _time,
                    onChanged: (v) => _time = v,
                    validator: (v) => v == null || v.isEmpty ? 'Enter time' : null,
                  ),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Message'),
                    initialValue: _message,
                    onChanged: (v) => _message = v,
                    validator: (v) => v == null || v.isEmpty ? 'Enter message' : null,
                  ),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Type'),
                    initialValue: _type,
                    onChanged: (v) => _type = v,
                    validator: (v) => v == null || v.isEmpty ? 'Enter type' : null,
                  ),
                  const SizedBox(height: 8),
                  _formLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _submitForm,
                          child: Text(_editing ? 'Update Reminder' : 'Add Reminder'),
                        ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          if (_loading)
            const CircularProgressIndicator()
          else if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red))
          else if (_reminders.isEmpty)
            const Text('No reminders found.')
          else
            Expanded(
              child: ListView.builder(
                itemCount: _reminders.length,
                itemBuilder: (context, index) {
                  final reminder = _reminders[index];
                  return ListTile(
                    leading: const Icon(Icons.alarm),
                    title: Text('Time: ${reminder.time}'),
                    subtitle: Text('Message: ${reminder.message}, Type: ${reminder.type}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _openEditForm(reminder),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteReminder(reminder.id),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class StepsScreen extends StatefulWidget {
  StepsScreen({super.key});

  @override
  State<StepsScreen> createState() => _StepsScreenState();
}

class _StepsScreenState extends State<StepsScreen> {
  final ApiService api = ApiService();
  int _todaySteps = 0;
  int _stepsGoal = 10000;
  bool _goalLoading = false;
  bool _editingGoal = false;
  String _goalInput = '';
  late MockStepsProvider _mockProvider;
  bool _started = false;
  List<Streak> _streaks = [];
  bool _streaksLoading = false;

  Map<String, dynamic>? _streakRanking;
  bool _rankingLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchStepsGoal();
    _fetchStreaks();
    _fetchStreakRanking();
    _startMockProvider();
  }

  Future<void> _fetchStepsGoal() async {
    setState(() { _goalLoading = true; });
    final settings = await api.fetchSettings();
    setState(() {
      _stepsGoal = settings?.stepsGoal ?? 10000;
      _goalInput = _stepsGoal.toString();
      _goalLoading = false;
    });
  }

  Future<void> _fetchStreaks() async {
    setState(() { _streaksLoading = true; });
    try {
      final streaks = await api.fetchStreaks();
      setState(() { _streaks = streaks; _streaksLoading = false; });
    } catch (e) {
      setState(() { _streaksLoading = false; });
    }
  }

  Future<void> _fetchStreakRanking() async {
    setState(() { _rankingLoading = true; });
    try {
      final ranking = await api.fetchStreakRanking('steps');
      setState(() { _streakRanking = ranking; _rankingLoading = false; });
    } catch (e) {
      setState(() { _rankingLoading = false; });
    }
  }

  Future<void> _updateStepsGoal() async {
    setState(() { _goalLoading = true; });
    final settings = await api.fetchSettings();
    if (settings != null) {
      final updated = await api.updateSettings(settings.copyWith(stepsGoal: int.tryParse(_goalInput) ?? _stepsGoal));
      if (updated != null) {
        final refreshed = await api.fetchSettings();
        setState(() {
          _stepsGoal = refreshed?.stepsGoal ?? updated.stepsGoal;
          _editingGoal = false;
        });
        _fetchStreaks(); // Refresh streaks after goal update
      }
    }
    setState(() { _goalLoading = false; });
  }

  void _startMockProvider() {
    if (_started) return;
    _mockProvider = MockStepsProvider(onStep: (steps) {
      setState(() { _todaySteps = steps; });

      // Create steps record every 100 steps and refresh streaks
      if (steps % 100 == 0 && steps > 0) {
        _createStepsRecord(steps);
      }

      // Refresh streaks when approaching or reaching the goal
      if (steps >= _stepsGoal * 0.9) { // When at 90% of goal
        _fetchStreaks();
        _fetchStreakRanking();
      }
    });
    _mockProvider.start();
    _started = true;
  }

  Future<void> _createStepsRecord(int steps) async {
    try {
      await api.createStepsRecord(steps);
      _fetchStreaks(); // Refresh streaks after creating steps record
      _fetchStreakRanking();
    } catch (e) {
      // Silently handle errors for mock data
    }
  }

  @override
  void dispose() {
    _mockProvider.stop();
    super.dispose();
  }

  Streak? get _stepsStreak {
    return _streaks.where((s) => s.type == 'steps').firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final stepsStreak = _stepsStreak;
    final isGoalAchieved = _todaySteps >= _stepsGoal;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Steps', style: Theme.of(context).textTheme.headlineMedium),
              _goalLoading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : IconButton(
                      icon: Icon(_editingGoal ? Icons.check : Icons.edit),
                      onPressed: () {
                        if (_editingGoal) {
                          _updateStepsGoal();
                        } else {
                          setState(() { _editingGoal = true; });
                        }
                      },
                    ),
            ],
          ),
          if (_editingGoal)
            TextField(
              decoration: const InputDecoration(labelText: 'Daily Steps Goal'),
              keyboardType: TextInputType.number,
              onChanged: (v) => _goalInput = v,
              controller: TextEditingController(text: _goalInput),
            ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (_todaySteps / (_stepsGoal > 0 ? _stepsGoal : 1)).clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
          ),
          const SizedBox(height: 4),
          Text('Today: $_todaySteps / $_stepsGoal steps'),

          // Streak Information
          const SizedBox(height: 16),
          if (_streaksLoading)
            const CircularProgressIndicator()
          else if (stepsStreak != null)
            Card(
              color: isGoalAchieved ? Colors.blue.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isGoalAchieved ? Icons.local_fire_department : Icons.trending_up,
                          color: isGoalAchieved ? Colors.blue : Colors.grey,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Steps Streak',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current: ${stepsStreak.current} days',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: isGoalAchieved ? Colors.blue : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Longest: ${stepsStreak.longest} days',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            if (_streakRanking != null)
                              Text(
                                'Ranking: #${_streakRanking!['rating']} among friends',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (isGoalAchieved)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Goal Achieved!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            if (_rankingLoading)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh Streaks'),
            onPressed: () {
              _fetchStreaks();
              _fetchStreakRanking();
            },
          ),
        ],
      ),
    );
  }
}

class FeedScreen extends StatefulWidget {
  FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final ApiService api = ApiService();
  List<dynamic> _activities = [];
  bool _loading = false;
  String? _error;
  String _typeFilter = '';
  DateTime? _startDate;
  DateTime? _endDate;

  final List<String> _typeOptions = [
    '', 'workout', 'diet', // Only show workout and diet
  ];

  @override
  void initState() {
    super.initState();
    _fetchFeed();
  }

  Future<void> _fetchFeed() async {
    setState(() { _loading = true; });
    try {
      final activities = await api.getFriendsFeed();
      setState(() { _activities = activities; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Failed to load feed'; _loading = false; });
    }
  }

  List<dynamic> get _filteredActivities {
    return _activities.where((a) {
      if (a['type'] != 'workout' && a['type'] != 'diet') return false;
      if (_typeFilter.isNotEmpty && a['type'] != _typeFilter) return false;
      if (_startDate != null) {
        final created = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(2000);
        if (created.isBefore(_startDate!)) return false;
      }
      if (_endDate != null) {
        final created = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(2100);
        if (created.isAfter(_endDate!)) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() { _startDate = picked; });
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() { _endDate = picked; });
  }

  Widget _buildActivityTile(dynamic a) {
    final type = a['type'];
    Map<String, dynamic> data = {};
    try {
      data = a['data'] is String ? Map<String, dynamic>.from(jsonDecode(a['data'])) : Map<String, dynamic>.from(a['data'] ?? {});
    } catch (_) {}
    final friendName = a['user_name'] ?? a['username'] ?? a['name'] ?? 'Someone';
    if (type == 'workout') {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.fitness_center),
          title: Text('$friendName did a workout'),
          subtitle: Text(
            'Type: \\${data['type'] ?? ''}\nDuration: \\${data['duration'] ?? ''} min\nIntensity: \\${data['intensity'] ?? ''}\nCalories: \\${data['calories'] ?? ''}\nLocation: \\${data['location'] ?? ''}\nAt: \\${a['created_at'] ?? ''}',
          ),
        ),
      );
    } else if (type == 'diet') {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.restaurant),
          title: Text('$friendName logged a meal'),
          subtitle: Text(
            'Meal: \\${data['meal'] ?? ''}\nFood: \\${data['food'] ?? ''}\nCalories: \\${data['calories'] ?? ''}\nAt: \\${a['created_at'] ?? ''}',
          ),
        ),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Friends Feed', style: Theme.of(context).textTheme.headlineMedium),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchFeed),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _typeFilter,
                  items: _typeOptions.map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(type.isEmpty ? 'All Types' : type),
                  )).toList(),
                  onChanged: (v) => setState(() { _typeFilter = v ?? ''; }),
                  decoration: const InputDecoration(labelText: 'Type'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _pickStartDate,
                child: Text(_startDate != null ? 'From: ' + DateFormat('yyyy-MM-dd').format(_startDate!) : 'From'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _pickEndDate,
                child: Text(_endDate != null ? 'To: ' + DateFormat('yyyy-MM-dd').format(_endDate!) : 'To'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loading) const CircularProgressIndicator(),
          if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
          if (_filteredActivities.isEmpty && !_loading)
            const Text('No activities found.'),
          if (_filteredActivities.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _filteredActivities.length,
                itemBuilder: (context, index) {
                  final a = _filteredActivities[index];
                  return _buildActivityTile(a);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final User friend;
  ChatScreen({required this.friend});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ApiService api = ApiService();
  List<dynamic> _messages = [];
  bool _loading = false;
  String? _error;
  final TextEditingController _controller = TextEditingController();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchMessages());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchMessages() async {
    setState(() { _loading = true; });
    try {
      final messages = await api.getChatHistory(widget.friend.id);
      setState(() { _messages = messages; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Failed to load messages'; _loading = false; });
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    await api.sendChatMessage(widget.friend.id, text);
    _controller.clear();
    _fetchMessages();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.friend.name)),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    reverse: true,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final m = _messages[_messages.length - 1 - index];
                      final isMe = m['from_user_id'] == api.currentUserId;
                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.blue : Colors.grey[300],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            m['content'],
                            style: TextStyle(color: isMe ? Colors.white : Colors.black),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(hintText: 'Type a message...'),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: _sendMessage,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

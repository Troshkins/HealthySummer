import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isAuthenticated = false;
  bool _showLogin = true;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isAuthenticated = prefs.getString('jwt') != null;
    });
  }

  void _onAuthenticated() {
    setState(() {
      _isAuthenticated = true;
    });
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
    if (!_isAuthenticated) {
      return MaterialApp(
        title: 'Healthy Summer',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        ),
        home: _showLogin
            ? LoginScreen(onAuthenticated: _onAuthenticated, onSwitch: _toggleAuthScreen)
            : RegisterScreen(onRegistered: _onAuthenticated, onSwitch: _toggleAuthScreen),
      );
    }
    return MaterialApp(
      title: 'Healthy Summer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
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
      // Auto-login after registration
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
    UsersScreen(),
    WorkoutsScreen(),
    WaterScreen(),
    DietScreen(),
    PeriodsScreen(),
    AwardsScreen(),
    JourneyScreen(),
    HealthRecordsScreen(),
    RemindersScreen(),
    ProfileScreen(),
    SettingsScreen(),
  ];

  static const List<BottomNavigationBarItem> _navItems = [
    BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
    BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: 'Workouts'),
    BottomNavigationBarItem(icon: Icon(Icons.local_drink), label: 'Water'),
    BottomNavigationBarItem(icon: Icon(Icons.restaurant), label: 'Diet'),
    BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Periods'),
    BottomNavigationBarItem(icon: Icon(Icons.emoji_events), label: 'Awards'),
    BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Journey'),
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

class UsersScreen extends StatelessWidget {
  final ApiService api = ApiService();

  UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<User>>(
      future: api.fetchUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        } else if (snapshot.hasError) {
          return Text('Error: \\${snapshot.error}');
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text('No users found.');
        } else {
          final users = snapshot.data!;
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                leading: CircleAvatar(child: Text(user.name[0])),
                title: Text(user.name),
                subtitle: Text(user.email),
              );
            },
          );
        }
      },
    );
  }
}

class WorkoutsScreen extends StatefulWidget {
  WorkoutsScreen({super.key});

  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen> {
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
  String _duration = '';

  @override
  void initState() {
    super.initState();
    _fetchWorkouts();
  }

  Future<void> _fetchWorkouts() async {
    setState(() { _loading = true; });
    try {
      final workouts = await api.fetchWorkouts();
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
      _duration = '';
    });
  }

  void _openEditForm(Workout workout) {
    setState(() {
      _showForm = true;
      _editing = true;
      _editingWorkout = workout;
      _type = workout.type;
      _duration = workout.duration.toString();
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _formLoading = true; });
    if (_editing && _editingWorkout != null) {
      final updated = await api.updateWorkout(Workout(
        id: _editingWorkout!.id,
        userId: _editingWorkout!.userId,
        type: _type,
        duration: int.tryParse(_duration) ?? 0,
      ));
      setState(() { _formLoading = false; _showForm = false; });
      if (updated != null) {
        _fetchWorkouts();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Workout updated')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update workout')));
      }
    } else {
      final created = await api.createWorkout(Workout(
        id: 0,
        userId: 0,
        type: _type,
        duration: int.tryParse(_duration) ?? 0,
      ));
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Workouts', style: Theme.of(context).textTheme.headlineMedium),
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
                    validator: (v) => v == null || v.isEmpty ? 'Enter workout type' : null,
                  ),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Duration (minutes)'),
                    initialValue: _duration,
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _duration = v,
                    validator: (v) => v == null || v.isEmpty ? 'Enter duration' : null,
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
                    subtitle: Text('Duration: ${w.duration} min'),
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

  @override
  void initState() {
    super.initState();
    _fetchWaterIntakes();
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
                    title: Text('Amount: \\${water.amount} ml'),
                    subtitle: Text('User ID: \\${water.userId}'),
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

  @override
  void initState() {
    super.initState();
    _fetchDietEntries();
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
                    title: Text('Meal: \\${diet.meal}'),
                    subtitle: Text('Food: \\${diet.food}, Calories: \\${diet.calories}, User ID: \\${diet.userId}'),
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
                    title: Text('Start: \\${period.start}'),
                    subtitle: Text('End: \\${period.end}, User ID: \\${period.userId}'),
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
                subtitle: Text('Desc: \\${award.desc}, User ID: \\${award.userId}'),
              );
            },
          );
        }
      },
    );
  }
}

class JourneyScreen extends StatelessWidget {
  final ApiService api = ApiService();

  JourneyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Journey>>(
      future: api.fetchJourneys(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        } else if (snapshot.hasError) {
          return Text('Error: \\${snapshot.error}');
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text('No journey posts found.');
        } else {
          final journeys = snapshot.data!;
          return ListView.builder(
            itemCount: journeys.length,
            itemBuilder: (context, index) {
              final journey = journeys[index];
              return ListTile(
                leading: const Icon(Icons.book),
                title: Text(journey.content),
                subtitle: Text('Date: \\${journey.date}, User ID: \\${journey.userId}'),
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
                    title: Text('Type: \\${record.type}'),
                    subtitle: Text('Value: \\${record.value}, Date: \\${record.date}, User ID: \\${record.userId}'),
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
      } else {
        _error = 'Failed to load profile';
      }
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    final user = await api.updateMe(_name!, _email!);
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
                        onPressed: _saveProfile,
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
      notificationsEnabled: _notificationsEnabled ?? true,
      theme: _theme ?? 'light',
    );
    final updated = await api.updateSettings(settings);
    setState(() { _loading = false; });
    if (updated != null) {
      setState(() { _editing = false; });
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
                    title: Text('Time: \\${reminder.time}'),
                    subtitle: Text('Message: \\${reminder.message}, Type: \\${reminder.type}'),
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

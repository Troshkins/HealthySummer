import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Settings {
  final bool notificationsEnabled;
  final String theme;

  Settings({required this.notificationsEnabled, required this.theme});

  factory Settings.fromJson(Map<String, dynamic> json) {
    return Settings(
      notificationsEnabled: json['notificationsEnabled'] ?? true,
      theme: json['theme'] ?? 'light',
    );
  }

  Map<String, dynamic> toJson() => {
    'notificationsEnabled': notificationsEnabled,
    'theme': theme,
  };
}

class Reminder {
  final int id;
  final String time;
  final String message;
  final String type;

  Reminder({required this.id, required this.time, required this.message, required this.type});

  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id'],
      time: json['time'],
      message: json['message'],
      type: json['type'],
    );
  }

  Map<String, dynamic> toJson() => {
    'time': time,
    'message': message,
    'type': type,
  };
}

class ApiService {
  static const String baseUrl = 'http://localhost:8080';

  Future<bool> register(String name, String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'name': name, 'email': email, 'password': password}),
    );
    return response.statusCode == 201;
  }

  Future<String?> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final token = data['token'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt', token);
      return token;
    } else {
      return null;
    }
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt');
  }

  Future<List<User>> fetchUsers() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/users'),
      headers: token != null ? {'Authorization': 'Bearer $token'} : {},
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => User.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load users');
    }
  }

  Future<List<Workout>> fetchWorkouts() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/workouts'),
      headers: token != null ? {'Authorization': 'Bearer $token'} : {},
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Workout.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load workouts');
    }
  }

  Future<List<WaterIntake>> fetchWaterIntakes() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/water'),
      headers: token != null ? {'Authorization': 'Bearer $token'} : {},
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => WaterIntake.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load water intakes');
    }
  }

  Future<List<DietEntry>> fetchDietEntries() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/diet'),
      headers: token != null ? {'Authorization': 'Bearer $token'} : {},
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => DietEntry.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load diet entries');
    }
  }

  Future<List<Period>> fetchPeriods() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/periods'),
      headers: token != null ? {'Authorization': 'Bearer $token'} : {},
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Period.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load periods');
    }
  }

  Future<List<Award>> fetchAwards() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/awards'),
      headers: token != null ? {'Authorization': 'Bearer $token'} : {},
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Award.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load awards');
    }
  }

  Future<List<Journey>> fetchJourneys() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/journeys'),
      headers: token != null ? {'Authorization': 'Bearer $token'} : {},
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Journey.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load journeys');
    }
  }

  Future<List<HealthRecord>> fetchHealthRecords() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/healthrecords'),
      headers: token != null ? {'Authorization': 'Bearer $token'} : {},
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => HealthRecord.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load health records');
    }
  }

  Future<List<Reminder>> fetchReminders() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/reminders'),
      headers: token != null ? {'Authorization': 'Bearer $token'} : {},
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Reminder.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load reminders');
    }
  }

  Future<Reminder?> createReminder(Reminder reminder) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/reminders'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: json.encode(reminder.toJson()),
    );
    if (response.statusCode == 201) {
      return Reminder.fromJson(json.decode(response.body));
    } else {
      return null;
    }
  }

  Future<Reminder?> updateReminder(Reminder reminder) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/reminders/${reminder.id}'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'time': reminder.time,
        'message': reminder.message,
        'type': reminder.type,
      }),
    );
    if (response.statusCode == 200) {
      return Reminder.fromJson(json.decode(response.body));
    } else {
      return null;
    }
  }

  Future<bool> deleteReminder(int id) async {
    final token = await getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/reminders/$id'),
      headers: token != null ? {'Authorization': 'Bearer $token'} : {},
    );
    return response.statusCode == 200;
  }

  Future<User?> getMe() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/me'),
      headers: token != null ? {'Authorization': 'Bearer $token'} : {},
    );
    if (response.statusCode == 200) {
      return User.fromJson(json.decode(response.body));
    } else {
      return null;
    }
  }

  Future<User?> updateMe(String name, String email) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/me'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: json.encode({'name': name, 'email': email}),
    );
    if (response.statusCode == 200) {
      return User.fromJson(json.decode(response.body));
    } else {
      return null;
    }
  }

  Future<Settings?> getSettings() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/settings'),
      headers: token != null ? {'Authorization': 'Bearer $token'} : {},
    );
    if (response.statusCode == 200) {
      return Settings.fromJson(json.decode(response.body));
    } else {
      return null;
    }
  }

  Future<Settings?> updateSettings(Settings settings) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/settings'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: json.encode(settings.toJson()),
    );
    if (response.statusCode == 200) {
      return Settings.fromJson(json.decode(response.body));
    } else {
      return null;
    }
  }

  Future<Workout?> createWorkout(Workout workout) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/workouts'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'type': workout.type,
        'duration': workout.duration,
      }),
    );
    if (response.statusCode == 201) {
      return Workout.fromJson(json.decode(response.body));
    } else {
      return null;
    }
  }

  Future<Workout?> updateWorkout(Workout workout) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/workouts/${workout.id}'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'type': workout.type,
        'duration': workout.duration,
      }),
    );
    if (response.statusCode == 200) {
      return Workout.fromJson(json.decode(response.body));
    } else {
      return null;
    }
  }

  Future<bool> deleteWorkout(int id) async {
    final token = await getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/workouts/$id'),
      headers: token != null ? {'Authorization': 'Bearer $token'} : {},
    );
    return response.statusCode == 200;
  }

  Future<WaterIntake?> createWaterIntake(WaterIntake waterIntake) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/water'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'amount': waterIntake.amount,
      }),
    );
    if (response.statusCode == 201) {
      return WaterIntake.fromJson(json.decode(response.body));
    } else {
      return null;
    }
  }

  Future<WaterIntake?> updateWaterIntake(WaterIntake waterIntake) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/water/${waterIntake.id}'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'amount': waterIntake.amount,
      }),
    );
    if (response.statusCode == 200) {
      return WaterIntake.fromJson(json.decode(response.body));
    } else {
      return null;
    }
  }

  Future<bool> deleteWaterIntake(int id) async {
    final token = await getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/water/$id'),
      headers: token != null ? {'Authorization': 'Bearer $token'} : {},
    );
    return response.statusCode == 200;
  }

  Future<DietEntry?> createDietEntry(DietEntry dietEntry) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/diet'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'meal': dietEntry.meal,
        'food': dietEntry.food,
        'calories': dietEntry.calories,
      }),
    );
    if (response.statusCode == 201) {
      return DietEntry.fromJson(json.decode(response.body));
    } else {
      return null;
    }
  }

  Future<DietEntry?> updateDietEntry(DietEntry dietEntry) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/diet/${dietEntry.id}'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'meal': dietEntry.meal,
        'food': dietEntry.food,
        'calories': dietEntry.calories,
      }),
    );
    if (response.statusCode == 200) {
      return DietEntry.fromJson(json.decode(response.body));
    } else {
      return null;
    }
  }

  Future<bool> deleteDietEntry(int id) async {
    final token = await getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/diet/$id'),
      headers: token != null ? {'Authorization': 'Bearer $token'} : {},
    );
    return response.statusCode == 200;
  }

  Future<Period?> createPeriod(Period period) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/periods'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'start': period.start,
        'end': period.end,
      }),
    );
    if (response.statusCode == 201) {
      return Period.fromJson(json.decode(response.body));
    } else {
      return null;
    }
  }

  Future<Period?> updatePeriod(Period period) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/periods/${period.id}'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'start': period.start,
        'end': period.end,
      }),
    );
    if (response.statusCode == 200) {
      return Period.fromJson(json.decode(response.body));
    } else {
      return null;
    }
  }

  Future<bool> deletePeriod(int id) async {
    final token = await getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/periods/$id'),
      headers: token != null ? {'Authorization': 'Bearer $token'} : {},
    );
    return response.statusCode == 200;
  }

  Future<HealthRecord?> createHealthRecord(HealthRecord record) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/healthrecords'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'type': record.type,
        'value': record.value,
        'date': record.date,
      }),
    );
    if (response.statusCode == 201) {
      return HealthRecord.fromJson(json.decode(response.body));
    } else {
      return null;
    }
  }

  Future<HealthRecord?> updateHealthRecord(HealthRecord record) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/healthrecords/${record.id}'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'type': record.type,
        'value': record.value,
        'date': record.date,
      }),
    );
    if (response.statusCode == 200) {
      return HealthRecord.fromJson(json.decode(response.body));
    } else {
      return null;
    }
  }

  Future<bool> deleteHealthRecord(int id) async {
    final token = await getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/healthrecords/$id'),
      headers: token != null ? {'Authorization': 'Bearer $token'} : {},
    );
    return response.statusCode == 200;
  }
}

class User {
  final int id;
  final String name;
  final String email;

  User({required this.id, required this.name, required this.email});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
    );
  }
}

class Workout {
  final int id;
  final int userId;
  final String type;
  final int duration;

  Workout({required this.id, required this.userId, required this.type, required this.duration});

  factory Workout.fromJson(Map<String, dynamic> json) {
    return Workout(
      id: json['id'],
      userId: json['user_id'],
      type: json['type'],
      duration: json['duration'],
    );
  }
}

class WaterIntake {
  final int id;
  final int userId;
  final int amount;

  WaterIntake({required this.id, required this.userId, required this.amount});

  factory WaterIntake.fromJson(Map<String, dynamic> json) {
    return WaterIntake(
      id: json['id'],
      userId: json['user_id'],
      amount: json['amount'],
    );
  }
}

class DietEntry {
  final int id;
  final int userId;
  final String meal;
  final String food;
  final int calories;

  DietEntry({required this.id, required this.userId, required this.meal, required this.food, required this.calories});

  factory DietEntry.fromJson(Map<String, dynamic> json) {
    return DietEntry(
      id: json['id'],
      userId: json['user_id'],
      meal: json['meal'],
      food: json['food'],
      calories: json['calories'],
    );
  }
}

class Period {
  final int id;
  final int userId;
  final String start;
  final String end;

  Period({required this.id, required this.userId, required this.start, required this.end});

  factory Period.fromJson(Map<String, dynamic> json) {
    return Period(
      id: json['id'],
      userId: json['user_id'],
      start: json['start'],
      end: json['end'],
    );
  }
}

class Award {
  final int id;
  final int userId;
  final String title;
  final String desc;

  Award({required this.id, required this.userId, required this.title, required this.desc});

  factory Award.fromJson(Map<String, dynamic> json) {
    return Award(
      id: json['id'],
      userId: json['user_id'],
      title: json['title'],
      desc: json['desc'],
    );
  }
}

class Journey {
  final int id;
  final int userId;
  final String content;
  final String date;

  Journey({required this.id, required this.userId, required this.content, required this.date});

  factory Journey.fromJson(Map<String, dynamic> json) {
    return Journey(
      id: json['id'],
      userId: json['user_id'],
      content: json['content'],
      date: json['date'],
    );
  }
}

class HealthRecord {
  final int id;
  final int userId;
  final String type;
  final String value;
  final String date;

  HealthRecord({required this.id, required this.userId, required this.type, required this.value, required this.date});

  factory HealthRecord.fromJson(Map<String, dynamic> json) {
    return HealthRecord(
      id: json['id'],
      userId: json['user_id'],
      type: json['type'],
      value: json['value'],
      date: json['date'],
    );
  }
}
import 'dart:convert';

class Friend {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final String? location;
  final String? status; // e.g., 'friend', 'pending', 'requested', etc.

  Friend({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.location,
    this.status,
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      avatarUrl: json['avatarUrl'] ?? json['avatar'] ?? json['picture']?['large'],
      location: json['location'] ?? json['location_state'],
      status: json['status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'avatarUrl': avatarUrl,
      'location': location,
      'status': status,
    };
  }

  static List<Friend> listFromJson(String response) {
    final decoded = json.decode(response);
    if (decoded is List) {
      return decoded.map((e) => Friend.fromJson(e)).toList();
    } else if (decoded is Map && decoded['results'] is List) {
      return (decoded['results'] as List).map((e) => Friend.fromJson(e)).toList();
    }
    return [];
  }
}
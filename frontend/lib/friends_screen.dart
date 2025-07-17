import 'package:flutter/material.dart';
import 'friend.dart';
import 'services/api_service.dart';
import 'chat_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({Key? key}) : super(key: key);

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final ApiService api = ApiService();
  List<Friend> _friends = [];
  List<Friend> _searchResults = [];
  List<dynamic> _incomingRequests = [];
  List<dynamic> _outgoingRequests = [];
  String _searchQuery = '';
  bool _loading = false;
  bool _searching = false;
  String? _error;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _fetchRequestsAndFriends();
  }

  Future<void> _fetchRequestsAndFriends() async {
    setState(() { _loading = true; _error = null; });
    try {
      final reqResp = await api.getFriendRequests();
      final friends = await api.fetchFriends();
      setState(() {
        _incomingRequests = reqResp['incoming'] ?? [];
        _outgoingRequests = reqResp['outgoing'] ?? [];
        _friends = friends;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = 'Failed to load friends/requests'; _loading = false; });
    }
  }

  Future<void> _searchUsers(String query) async {
    setState(() { _searching = true; _searchError = null; });
    try {
      final results = await api.searchUsers(query);
      setState(() {
        _searchResults = results.map((u) => Friend(
          id: u.id.toString(),
          name: u.name,
          email: u.email,
          avatarUrl: null, // User does not have avatarUrl
          location: null,  // User does not have location
          status: null,
        )).toList();
        _searching = false;
      });
    } catch (e) {
      setState(() { _searchError = 'Search failed'; _searching = false; });
    }
  }

  Future<void> _sendFriendRequest(String toUserId) async {
    await api.sendFriendRequest(int.parse(toUserId));
    _fetchRequestsAndFriends();
  }

  Future<void> _acceptRequest(String requestId) async {
    await api.acceptFriendRequest(int.parse(requestId));
    _fetchRequestsAndFriends();
  }

  Future<void> _rejectRequest(String requestId) async {
    await api.rejectFriendRequest(int.parse(requestId));
    _fetchRequestsAndFriends();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Friends', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(labelText: 'Search users by name or email'),
              onChanged: (v) => _searchQuery = v,
              onSubmitted: _searchUsers,
            ),
            if (_searching) const LinearProgressIndicator(),
            if (_searchError != null) Text(_searchError!, style: const TextStyle(color: Colors.red)),
            if (_searchResults.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  const Text('Search Results:'),
                  ..._searchResults.map((u) {
                    final isFriend = _friends.any((f) => f.id == u.id);
                    final isPending = _outgoingRequests.any((r) => r['to_user_id'].toString() == u.id);
                    final isIncoming = _incomingRequests.any((r) => r['from_user_id'].toString() == u.id);
                    Widget trailingWidget;
                    if (isFriend) {
                      trailingWidget = const Text('Already Friends');
                    } else if (isPending) {
                      trailingWidget = const Text('Pending');
                    } else if (isIncoming) {
                      trailingWidget = const Text('Request Received');
                    } else {
                      trailingWidget = ElevatedButton(
                        onPressed: () => _sendFriendRequest(u.id),
                        child: const Text('Add Friend'),
                      );
                    }
                    return ListTile(
                      title: Text(u.name),
                      subtitle: Text(u.email),
                      trailing: trailingWidget,
                    );
                  }),
                ],
              ),
            const SizedBox(height: 24),
            if (_loading) const CircularProgressIndicator(),
            if (_incomingRequests.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Incoming Requests:'),
                  ..._incomingRequests.map((r) => ListTile(
                    title: Text('From User ID: ${r['from_user_id']}'),
                    subtitle: Text('Request ID: ${r['id']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.check), onPressed: () => _acceptRequest(r['id'].toString())),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => _rejectRequest(r['id'].toString())),
                      ],
                    ),
                  )),
                ],
              ),
            if (_outgoingRequests.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Outgoing Requests:'),
                  ..._outgoingRequests.map((r) {
                    final user = _searchResults.firstWhere(
                      (u) => u.id == r['to_user_id'].toString(),
                      orElse: () => Friend(
                        id: r['to_user_id'].toString(),
                        name: 'Unknown',
                        email: '',
                      ),
                    );
                    return ListTile(
                      title: Text(user.name),
                      subtitle: Text(user.email.isNotEmpty ? user.email : 'Request ID: ${r['id']}'),
                      trailing: const Text('Pending'),
                    );
                  }),
                ],
              ),
            const SizedBox(height: 24),
            if (_friends.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Your Friends:'),
                  ..._friends.map((u) => ListTile(
                    title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.normal)),
                    subtitle: Text(u.email),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(friend: u),
                      ),
                    ),
                  )),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
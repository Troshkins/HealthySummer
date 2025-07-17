import 'package:flutter/material.dart';
import 'friend.dart';
import 'services/api_service.dart';
import 'dart:async';

class ChatScreen extends StatefulWidget {
  final Friend friend;
  const ChatScreen({Key? key, required this.friend}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ApiService api = ApiService();
  List<Message> _messages = [];
  bool _loading = false;
  String? _error;
  final TextEditingController _controller = TextEditingController();
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchMessages());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages() async {
    setState(() { _loading = true; _error = null; });
    try {
      final messages = await api.getChatHistory(int.parse(widget.friend.id));
      setState(() {
        _messages = messages;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = 'Failed to load messages'; _loading = false; });
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    try {
      await api.sendChatMessage(int.parse(widget.friend.id), text);
      _controller.clear();
      _fetchMessages();
    } catch (e) {
      setState(() { _error = 'Failed to send message'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = api.currentUserId;
    return Scaffold(
      appBar: AppBar(title: Text('Chat with ${widget.friend.name}')),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                    : ListView.builder(
                        reverse: true,
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[_messages.length - 1 - index];
                          final isMe = msg.senderId == currentUserId;
                          print('currentUserId: $currentUserId, senderId: ${msg.senderId}, isMe: $isMe');
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            padding: const EdgeInsets.all(12),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.blue[300] : Colors.grey[300],
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                                bottomLeft: Radius.circular(16),
                                bottomRight: Radius.circular(16),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(msg.content),
                                const SizedBox(height: 4),
                                Text(
                                  msg.timestamp.toLocal().toString().substring(0, 16),
                                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
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
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:socail_media_app/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:socail_media_app/features/chat/domain/entities/message.dart';
import 'package:socail_media_app/features/chat/presentation/cubits/chat_cubit.dart';
import 'package:socail_media_app/features/profile/domain/entities/profile_user.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final ProfileUser otherUser;
  final bool isNewChat;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherUser,
    this.isNewChat = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late String _chatId;
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _chatId = widget.chatId;

    if (widget.isNewChat) {
      _createNewChat();
    } else {
      _markMessagesAsRead();
    }
  }

  Future<void> _createNewChat() async {
    try {
      _chatId =
          await context.read<ChatCubit>().createNewChat(widget.otherUser.uid);
      _markMessagesAsRead();
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка создания чата: $e')),
      );
      Navigator.pop(context);
    }
  }

  void _markMessagesAsRead() {
    final currentUserId = context.read<AuthCubit>().currentUser!.uid;
    context.read<ChatCubit>().markAsRead(_chatId, currentUserId);
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty || _chatId.isEmpty) return;

    final message = Message(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      chatId: _chatId,
      senderId: context.read<AuthCubit>().currentUser!.uid,
      text: _messageController.text,
      timestamp: DateTime.now(),
    );

    context.read<ChatCubit>().sendMessage(message);
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUser.name),
      ),
      body: Column(
        children: [
          Expanded(
            child: _chatId.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<List<Message>>(
                    stream: context.read<ChatCubit>().getMessages(_chatId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(child: Text('Ошибка: ${snapshot.error}'));
                      }

                      final messages = snapshot.data ?? [];

                      return ListView.builder(
                        reverse: true,
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final isMe = message.senderId ==
                              context.read<AuthCubit>().currentUser!.uid;

                          return Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                  vertical: 4, horizontal: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color:
                                    isMe ? Colors.blue[100] : Colors.grey[300],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(message.text),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
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
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Введите сообщение...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                  color: Theme.of(context).primaryColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}

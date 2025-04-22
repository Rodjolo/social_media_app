import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:socail_media_app/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:socail_media_app/features/chat/presentation/cubits/chat_cubit.dart';
import 'package:socail_media_app/features/chat/presentation/pages/chat_screen.dart';
import 'package:socail_media_app/features/chat/presentation/pages/user_selection_screen.dart';
import 'package:socail_media_app/features/profile/domain/entities/profile_user.dart';
import 'package:socail_media_app/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:socail_media_app/features/search/presentation/cubits/search_cubit.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthCubit>().currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Чаты'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BlocProvider.value(
                  value: context.read<SearchCubit>(),
                  child: const UserSelectionScreen(),
                ),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: context.read<ChatCubit>().getUserChatsStream(currentUserId),
        builder: (context, snapshot) {
          // Добавляем обработку состояний
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Нет активных чатов'));
          }

          final chats = snapshot.data!;

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              final participants = List<String>.from(chat['participants'] as List);
              final otherUserId = participants.firstWhere(
                (id) => id != currentUserId,
              );

              return FutureBuilder<ProfileUser?>(
                future:
                    context.read<ProfileCubit>().getUserProfile(otherUserId),
                builder: (context, userSnapshot) {
                  // Обработка состояния загрузки пользователя
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return const ListTile(
                      leading: CircleAvatar(),
                      title: Text('Загрузка...'),
                    );
                  }

                  if (!userSnapshot.hasData || userSnapshot.data == null) {
                    return const ListTile(
                      title: Text('Пользователь не найден'),
                    );
                  }

                  final user = userSnapshot.data!;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(user.profileImageUrl),
                    ),
                    title: Text(user.name),
                    subtitle: Text(chat['lastMessage'] ?? ''),
                    trailing: (chat['unreadCount'] as int) > 0
                        ? Chip(label: Text(chat['unreadCount'].toString()))
                        : null,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BlocProvider.value(
                          value: context.read<ChatCubit>(),
                          child: ChatScreen(
                            chatId: chat['chatId'] as String,
                            otherUser: user,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

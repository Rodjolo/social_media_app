import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:socail_media_app/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:socail_media_app/features/chat/presentation/cubits/chat_cubit.dart';
import 'package:socail_media_app/features/chat/presentation/pages/chat_screen.dart';
import 'package:socail_media_app/features/profile/domain/entities/profile_user.dart';
import 'package:socail_media_app/features/search/presentation/cubits/search_cubit.dart';
import 'package:socail_media_app/features/search/presentation/cubits/search_states.dart';

class UserSelectionScreen extends StatefulWidget {
  const UserSelectionScreen({super.key});

  @override
  State<UserSelectionScreen> createState() => _UserSelectionScreenState();
}

class _UserSelectionScreenState extends State<UserSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Инициируем поиск всех пользователей при открытии
    context.read<SearchCubit>().searchUsers('');
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    context.read<SearchCubit>().searchUsers(_searchController.text);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Поиск пользователей...',
            border: InputBorder.none,
          ),
        ),
      ),
      body: BlocConsumer<SearchCubit, SearchState>(
        listener: (context, state) {
          if (state is SearchError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          if (state is SearchLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is SearchLoaded) {
            if (state.users.isEmpty) {
              return const Center(child: Text('Пользователи не найдены'));
            }
            return _buildUsersList(state.users);
          }
          return const Center(child: Text('Начните поиск пользователей'));
        },
      ),
    );
  }

  Widget _buildUsersList(List<ProfileUser?> users) {
    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        if (user == null) return const SizedBox();

        return ListTile(
          leading: CircleAvatar(
            backgroundImage: NetworkImage(user.profileImageUrl),
          ),
          title: Text(user.name),
          onTap: () => _createChat(context, user),
        );
      },
    );
  }

  void _createChat(BuildContext context, ProfileUser otherUser) async {
    final currentUser = context.read<AuthCubit>().currentUser!;
    if (currentUser.uid == otherUser.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нельзя создать чат с самим собой')),
      );
      return;
    }

    try {
      final chatId =
          await context.read<ChatCubit>().createNewChat(otherUser.uid);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chatId,
            otherUser: otherUser,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка создания чата: $e')),
      );
    }
  }
}

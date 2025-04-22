import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:socail_media_app/features/profile/presentation/components/user_tile.dart';
import 'package:socail_media_app/features/profile/presentation/cubit/profile_cubit.dart';

class FollowerPage extends StatelessWidget {
  final List<String> followers;
  final List<String> following;
  const FollowerPage({
    super.key,
    required this.followers,
    required this.following,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(

          // Tab Bar
          bottom: TabBar(
            dividerColor: Colors.transparent,
            labelColor: Theme.of(context).colorScheme.inversePrimary,
            unselectedLabelColor: Theme.of(context).colorScheme.primary,
            tabs: const [
              Tab(text: 'Подписчики'),
              Tab(text: 'Подписки'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildUserList(followers, 'Нет подписчиков', context),
            _buildUserList(following, 'Нет подписок', context),
          ],
        ),
      ),
    );
  }

  Widget _buildUserList(
      List<String> uids, String emptyMessage, BuildContext context) {
    return uids.isEmpty
        ? Center(child: Text(emptyMessage))
        : ListView.builder(
            itemCount: uids.length,
            itemBuilder: (context, index) {
              // get each uid
              final uid = uids[index];

              return FutureBuilder(
                future: context.read<ProfileCubit>().getUserProfile(uid),
                builder: (context, snapshot) {
                  // user loaded
                  if (snapshot.hasData) {
                    final user = snapshot.data!;
                    return UserTile(user: user);
                  }

                  // loading..
                  else if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const ListTile(title: Text('Загрузка..'));
                  }

                  // not found
                  else {
                    return const ListTile(title: Text('Пользвоатель не найден..'));
                  }
                },
              );
            },
          );
  }
}

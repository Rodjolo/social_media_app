import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:socail_media_app/features/chat/presentation/cubits/chat_cubit.dart';
import 'package:socail_media_app/features/chat/presentation/pages/chat_list_screen.dart';
import 'package:socail_media_app/features/home/presentation/components/my_drawer_tile.dart';
import 'package:socail_media_app/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:socail_media_app/features/search/presentation/cubits/pages/search_page.dart';
import 'package:socail_media_app/features/settings/pages/settings_page.dart';

import '../../../auth/presentation/cubits/auth_cubit.dart';
import '../../../profile/presentation/pages/profile_page.dart';

class MyDrawer extends StatelessWidget {
  const MyDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25.0),
          child: Column(
            children: [
              //logo
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 50.0),
                child: Icon(
                  Icons.person,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),

              Divider(
                color: Theme.of(context).colorScheme.secondary,
              ),

              //home tile
              MyDrawerTile(
                title: 'Г Л А В Н А Я',
                icon: Icons.home,
                onTap: () => Navigator.of(context).pop(),
              ),

              //profile tile
              MyDrawerTile(
                title: 'П Р О Ф И Л Ь',
                icon: Icons.person,
                onTap: () {
                  //pop menu drawer
                  Navigator.of(context).pop();

                  final user = context.read<AuthCubit>().currentUser;
                  String? uid = user!.uid;

                  //navigating to profile page
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfilePage(
                          uid: uid,
                        ),
                      ));
                },
              ),

              //chat tile
              MyDrawerTile(
                title: 'С О О Б Щ Е Н И Я',
                icon: Icons.chat,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MultiBlocProvider(
                        providers: [
                          BlocProvider.value(
                              value: context.read<ProfileCubit>()),
                          BlocProvider.value(value: context.read<ChatCubit>()),
                        ],
                        child: ChatListScreen(),
                      ),
                    ),
                  );
                },
              ),
              
              //search tile
              MyDrawerTile(
                title: 'П О И С К',
                icon: Icons.search,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SearchPage(),
                    )),
              ),

              //settings tile
              MyDrawerTile(
                title: 'Н А С Т Р О Й К И',
                icon: Icons.settings,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsPage(),
                    )),
              ),

              const Spacer(),

              //logout tile
              MyDrawerTile(
                title: 'В Ы Й Т И',
                icon: Icons.login,
                onTap: () => context.read<AuthCubit>().logout(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

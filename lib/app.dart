import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:socail_media_app/features/auth/data/firebase_auth_repo.dart';
import 'package:socail_media_app/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:socail_media_app/features/auth/presentation/cubits/auth_states.dart';
import 'package:socail_media_app/features/chat/domain/repos/firebase_chat_repo.dart';
import 'package:socail_media_app/features/chat/presentation/cubits/chat_cubit.dart';
import 'package:socail_media_app/features/post/presentation/cubits/post_cubit.dart';
import 'package:socail_media_app/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:socail_media_app/features/search/data/firebase_search_repo.dart';
import 'package:socail_media_app/features/search/presentation/cubits/search_cubit.dart';
import 'package:socail_media_app/features/storage/data/supabase_storage_repo.dart';
import 'package:socail_media_app/themes/theme_cubit.dart';
import 'features/auth/presentation/pages/auth_page.dart';
import 'features/home/presentation/pages/home_page.dart';
import 'features/post/data/firebase_post_repo.dart';
import 'features/profile/data/firebase_profile_repo.dart';

class MyApp extends StatelessWidget {
  //auth repo
  final firebaseAuthRepo = FirebaseAuthRepo();

  //profile repo
  final firebaseProfileRepo = FirebaseProfileRepo();

  //storage repo
  final supabaseStorageRepo = SupabaseStorageRepo();

  //post repo
  final firebasePostRepo = FirebasePostRepo();

  // serach repo
  final firebaseSearchRepo = FirebaseSearchRepo();

  // chat repo
  final firebaseChatRepo = FirebaseChatRepo();

  MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        //auth cubit
        BlocProvider<AuthCubit>(
          create: (context) =>
              AuthCubit(authRepo: firebaseAuthRepo)..checkAuth(),
        ),

        //profile cubit
        BlocProvider<ProfileCubit>(
          create: (context) => ProfileCubit(
            profileRepo: firebaseProfileRepo,
            storageRepo: supabaseStorageRepo,
          ),
        ),

        //post cubit
        BlocProvider<PostCubit>(
          create: (context) => PostCubit(
              postRepo: firebasePostRepo, storageRepo: supabaseStorageRepo),
        ),

        //search cubit
        BlocProvider<SearchCubit>(
          create: (context) => SearchCubit(searchRepo: firebaseSearchRepo),
        ),

        // chat cubit
        BlocProvider<ChatCubit>(
          create: (context) => ChatCubit(
            chatRepo: firebaseChatRepo,
            authCubit: context.read<AuthCubit>(),
          ),
        ),

        //theme cubit
        BlocProvider<ThemeCubit>(
          create: (context) => ThemeCubit(),
        ),
      ],

      // bloc builder: themes
      child: BlocBuilder<ThemeCubit, ThemeData>(
        builder: (context, currentTheme) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: currentTheme,

          // bloc builder: check current auth state
          home: BlocConsumer<AuthCubit, AuthState>(
            builder: (context, authState) {
              print(authState);

              if (authState is Unauthenticated) {
                return const AuthPage();
              }

              if (authState is Authenticated) {
                return const HomePage();
              } else {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }
            },

            //listen for errors
            listener: (context, state) {
              if (state is AuthError) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(state.message)));
              }
            },
          ),
        ),
      ),
    );
  }
}

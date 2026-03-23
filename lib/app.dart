import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:socail_media_app/features/auth/data/pocketbase_auth_repo.dart';
import 'package:socail_media_app/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:socail_media_app/features/auth/presentation/cubits/auth_states.dart';
import 'package:socail_media_app/features/movies/data/pocketbase_movie_repo.dart';
import 'package:socail_media_app/features/movies/presentation/cubits/movie_cubit.dart';
import 'package:socail_media_app/features/post/data/pocketbase_post_repo.dart';
import 'package:socail_media_app/features/post/presentation/cubits/post_cubit.dart';
import 'package:socail_media_app/features/profile/data/pocketbase_profile_repo.dart';
import 'package:socail_media_app/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:socail_media_app/features/search/data/pocketbase_search_repo.dart';
import 'package:socail_media_app/features/search/presentation/cubits/search_cubit.dart';
import 'package:socail_media_app/features/storage/data/pocketbase_storage_repo.dart';
import 'package:socail_media_app/themes/theme_cubit.dart';
import 'features/auth/presentation/pages/auth_page.dart';
import 'features/home/presentation/pages/home_page.dart';

class MyApp extends StatelessWidget {
  //auth repo
  final pocketBaseAuthRepo = PocketBaseAuthRepo();

  //profile repo
  final pocketBaseProfileRepo = PocketBaseProfileRepo();

  //storage repo
  final pocketBaseStorageRepo = PocketBaseStorageRepo();

  //post repo
  final pocketBasePostRepo = PocketBasePostRepo();

  // serach repo
  final pocketBaseSearchRepo = PocketBaseSearchRepo();

  // movie repo
  final pocketBaseMovieRepo = PocketBaseMovieRepo();

  MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        //auth cubit
        BlocProvider<AuthCubit>(
          create: (context) =>
              AuthCubit(authRepo: pocketBaseAuthRepo)..checkAuth(),
        ),

        //profile cubit
        BlocProvider<ProfileCubit>(
          create: (context) => ProfileCubit(
            profileRepo: pocketBaseProfileRepo,
            storageRepo: pocketBaseStorageRepo,
          ),
        ),

        //post cubit
        BlocProvider<PostCubit>(
          create: (context) => PostCubit(
            postRepo: pocketBasePostRepo,
            storageRepo: pocketBaseStorageRepo,
          ),
        ),

        //search cubit
        BlocProvider<SearchCubit>(
          create: (context) => SearchCubit(searchRepo: pocketBaseSearchRepo),
        ),

        BlocProvider<MovieCubit>(
          create: (context) => MovieCubit(movieRepo: pocketBaseMovieRepo),
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

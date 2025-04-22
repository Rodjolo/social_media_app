import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:socail_media_app/features/home/presentation/components/my_drawer.dart';
import 'package:socail_media_app/features/post/presentation/components/post_tile.dart';
import 'package:socail_media_app/features/post/presentation/cubits/post_cubit.dart';

import '../../../post/presentation/cubits/post_states.dart';
import '../../../post/presentation/pages/upload_post_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // post cubit
  late final postCubit = context.read<PostCubit>();

  @override
  void initState() {
    super.initState();

    // fetch all posts
    fetchAllPosts();
  }

  void fetchAllPosts() {
    postCubit.fetchAllPosts();
  }

  void deletePost(String postId) {
    postCubit.deletePost(postId);
    fetchAllPosts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Главная'),
        foregroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          IconButton(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UploadPostPage(),
                  )),
              icon: const Icon(Icons.add))
        ],
      ),
      drawer: const MyDrawer(),
      body: BlocBuilder<PostCubit, PostState>(
        builder: (context, state) {
          // loading ..
          if (state is PostLoading || state is PostUploading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          // loaded
          else if (state is PostLoaded) {
            final allposts = state.posts;

            if (allposts.isEmpty) {
              return const Center(
                child: Text('Нет доступных постов'),
              );
            }

            return ListView.builder(
              itemCount: allposts.length,
              itemBuilder: (context, index) {
                final post = allposts[index];

                // image
                return PostTile(
                  post: post,
                  onDeletePressed: () => deletePost(post.id),
                );
              },
            );
          }

          // error
          else if (state is PostError) {
            return Center(
              child: Text(state.message),
            );
          } else {
            return const SizedBox();
          }
        },
      ),
    );
  }
}

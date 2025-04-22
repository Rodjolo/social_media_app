import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:socail_media_app/features/auth/domain/entities/app_user.dart';
import 'package:socail_media_app/features/auth/presentation/components/my_text_field.dart';
import 'package:socail_media_app/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:socail_media_app/features/post/domain/enteties/comment.dart';
import 'package:socail_media_app/features/post/presentation/components/comment_tile.dart';
import 'package:socail_media_app/features/post/presentation/cubits/post_cubit.dart';
import 'package:socail_media_app/features/post/presentation/cubits/post_states.dart';
import 'package:socail_media_app/features/profile/domain/entities/profile_user.dart';
import 'package:socail_media_app/features/profile/presentation/pages/profile_page.dart';

import '../../domain/enteties/post.dart';
import '../../../profile/presentation/cubit/profile_cubit.dart';

class PostTile extends StatefulWidget {
  final Post post;
  final void Function()? onDeletePressed;
  const PostTile({
    super.key,
    required this.post,
    required this.onDeletePressed,
  });

  @override
  State<PostTile> createState() => _PostTileState();
}

class _PostTileState extends State<PostTile> {
  // cubits
  late final postCubit = context.read<PostCubit>();
  late final profileCubit = context.read<ProfileCubit>();

  bool isOwnPost = false;

  // current user
  AppUser? currentUser;

  // post user
  ProfileUser? postUser;

  @override
  void initState() {
    super.initState();

    getCurrentUser();
    fetchPostUser();
  }

  void getCurrentUser() {
    final authCubit = context.read<AuthCubit>();
    currentUser = authCubit.currentUser;
    isOwnPost = widget.post.userId == currentUser!.uid;
  }

  Future<void> fetchPostUser() async {
    final fetchedUser = await profileCubit.getUserProfile(widget.post.userId);
    if (fetchedUser != null) {
      setState(() {
        postUser = fetchedUser;
      });
    }
  }

  // user tapped like button
  void toggleLikePost() {
    final isLiked = widget.post.likes.contains(currentUser!.uid);

    setState(() {
      if (isLiked) {
        widget.post.likes.remove(currentUser!.uid);
      } else {
        widget.post.likes.add(currentUser!.uid);
      }
    });

    postCubit
        .toggleLikePost(widget.post.id, currentUser!.uid)
        .catchError((error) {
      setState(() {
        if (isLiked) {
          widget.post.likes.add(currentUser!.uid);
        } else {
          widget.post.likes.remove(currentUser!.uid);
        }
      });
    });
  }

  // comment text controller
  final commentTextController = TextEditingController();

  // open comment box -> user wants to type a new comment
  void openNewCommentBox() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: MyTextField(
          controller: commentTextController,
          hintText: 'Введите текст',
          obscureText: false,
        ),
        actions: [
          // cancel button
          TextButton(
            onPressed: () => Navigator.of(context).pop,
            child: const Text('Отменить'),
          ),

          // save button
          TextButton(
            onPressed: () {
              addComment();
              Navigator.of(context).pop();
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void addComment() {
    // create a new comment
    final newComment = Comment(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      postId: widget.post.id,
      userId: currentUser!.uid,
      userName: currentUser!.name,
      text: commentTextController.text,
      timestamp: DateTime.now(),
    );

    // add comment
    if (commentTextController.text.isNotEmpty) {
      postCubit.addComment(widget.post.id, newComment);
    }
  }

  @override
  void dispose() {
    commentTextController.dispose();
    super.dispose();
  }

  void showOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить пост?'),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Отмена')),
          TextButton(
              onPressed: () {
                widget.onDeletePressed!();
                Navigator.of(context).pop();
              },
              child: const Text('Удалить')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.secondary,
      child: Column(
        children: [
          // top section : profile pic / name / delete button
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProfilePage(uid: widget.post.userId),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // profile pic
                  postUser?.profileImageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: postUser!.profileImageUrl,
                          errorWidget: (context, url, error) =>
                              const Icon(Icons.person),
                          imageBuilder: (context, imageProvider) => Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                image: DecorationImage(
                                  image: imageProvider,
                                  fit: BoxFit.cover,
                                )),
                          ),
                        )
                      : const Icon(Icons.person),

                  const SizedBox(
                    width: 10,
                  ),

                  // name
                  Text(
                    widget.post.userName,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.inversePrimary,
                        fontWeight: FontWeight.bold),
                  ),

                  const Spacer(),

                  // delete button
                  if (isOwnPost)
                    GestureDetector(
                      onTap: showOptions,
                      child: Icon(
                        Icons.delete,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                ],
              ),
            ),
          ),

          // image
          CachedNetworkImage(
            imageUrl: widget.post.imageUrl,
            height: 430,
            width: double.infinity,
            fit: BoxFit.cover,
            placeholder: (context, url) => const SizedBox(
              height: 430,
            ),
            errorWidget: (context, url, error) => const Icon(Icons.error),
          ),

          // buttons: like, comment, timestamp
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                // like
                SizedBox(
                  width: 50,
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: toggleLikePost,
                        child: Icon(
                          widget.post.likes.contains(currentUser!.uid)
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: widget.post.likes.contains(currentUser!.uid)
                              ? Colors.red
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),

                      const SizedBox(
                        width: 5,
                      ),

                      // like counter
                      Text(
                        widget.post.likes.length.toString(),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  width: 20,
                ),
                // comment button
                GestureDetector(
                  onTap: openNewCommentBox,
                  child: Icon(
                    Icons.comment,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),

                const SizedBox(
                  width: 5,
                ),

                Text(
                  widget.post.comments.length.toString(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 12,
                  ),
                ),

                const Spacer(),
                // timestamp
                Text(widget.post.timestamp.toString())
              ],
            ),
          ),

          // Caption
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
            child: Row(
              children: [
                // username
                Text(
                  widget.post.userName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  width: 10,
                ),

                // text
                Text(widget.post.text),
              ],
            ),
          ),

          // Comment Section
          BlocBuilder<PostCubit, PostState>(
            builder: (context, state) {
              // loaded
              if (state is PostLoaded) {
                final post =
                    state.posts.firstWhere((post) => post.id == widget.post.id);

                if (post.comments.isNotEmpty) {
                  int showCommentCount = post.comments.length;

                  return ListView.builder(
                    itemCount: showCommentCount,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      final comment = post.comments[index];

                      // comment tile UI
                      return CommentTile(comment: comment);
                    },
                  );
                }
              }

              // loading
              if (state is PostLoading) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              } else if (state is PostError) {
                return Center(
                  child: Text(state.message),
                );
              } else {
                return const SizedBox();
              }
            },
          )
        ],
      ),
    );
  }
}

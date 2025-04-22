import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:socail_media_app/features/auth/domain/entities/app_user.dart';
import 'package:socail_media_app/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:socail_media_app/features/post/domain/enteties/comment.dart';
import 'package:socail_media_app/features/post/presentation/cubits/post_cubit.dart';

class CommentTile extends StatefulWidget {
  final Comment comment;
  const CommentTile({super.key, required this.comment});

  @override
  State<CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<CommentTile> {
  // current user
  AppUser? currentUser;
  bool isOwnPost = false;

  @override
  void initState() {
    super.initState();

    getCurrentUser();
  }

  void getCurrentUser() {
    final authCubit = context.read<AuthCubit>();
    currentUser = authCubit.currentUser;
    isOwnPost = (widget.comment.userId == currentUser!.uid);
  }

  void showOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить комментарий?'),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Отмена')),
          TextButton(
              onPressed: () {
                context
                    .read<PostCubit>()
                    .deleteComment(widget.comment.postId, widget.comment.id);
                Navigator.of(context).pop();
              },
              child: const Text('Удалить')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        children: [
          // name
          Text(
            widget.comment.userName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),

          const SizedBox(
            width: 10,
          ),

          // comment text
          Text(widget.comment.text),

          const Spacer(),

          // delete button
          if (isOwnPost)
            GestureDetector(
              onTap: showOptions,
              child: Icon(
                Icons.more_horiz,
                color: Theme.of(context).colorScheme.primary,
              ),
            )
        ],
      ),
    );
  }
}

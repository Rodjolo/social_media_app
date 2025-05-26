import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:socail_media_app/features/post/domain/enteties/comment.dart';
import 'package:socail_media_app/features/post/domain/repos/post_repo.dart';
import 'package:socail_media_app/features/storage/domain/storage_repo.dart';
import '../../domain/enteties/post.dart';
import 'post_states.dart';

class PostCubit extends Cubit<PostState> {
  final PostRepo postRepo;
  final StorageRepo storageRepo;

  PostCubit({
    required this.postRepo,
    required this.storageRepo,
  }) : super(PostInitial());

  // create a new post
  Future<void> createPost(Post post,
      {String? imagePath, Uint8List? imageBytes, String? fileName}) async {
    String imageUrl = '';

    try {
      if (imagePath != null && fileName != null) {
        emit(PostUploading());
        imageUrl =
            await storageRepo.uploadPostImageMobile(imagePath, fileName) ?? '';
      } else if (imageBytes != null && fileName != null) {
        emit(PostUploading());
        imageUrl =
            await storageRepo.uploadPostImageWeb(imageBytes, fileName) ?? '';
      }

      final newPost = post.copyWith(imageUrl: imageUrl);
      await postRepo.createPost(newPost);
      await fetchAllPosts();
    } catch (e) {
      emit(PostError(message: 'Ошибка при создании поста: ${e.toString()}'));
    }
  }

  // fetch all posts
  Future<void> fetchAllPosts() async {
    try {
      emit(PostLoading());
      final posts = await postRepo.fetchAllPosts();
      emit(PostLoaded(posts: posts));
    } catch (e) {
      emit(PostError(message: 'Ошибка при обновлении поста: $e'));
    }
  }

  // delete a post
  Future<void> deletePost(String postId) async {
    try {
      await postRepo.deletePost(postId);
    } catch (e) {
      PostError(message: 'Ошбика при удалении поста: $e');
    }
  }

  // toggle like on a post
  Future<void> toggleLikePost(String postId, String userId) async {
    try {
      await postRepo.toggleLikePost(postId, userId);
    } catch (e) {
      emit(PostError(message: 'Ошибка в учтении лайка: $e'));
    }
  }

  // add a comment to a post
  Future<void> addComment(String postId, Comment comment) async {
    try {
      await postRepo.addComment(postId, comment);

      await fetchAllPosts();
    } catch (e) {
      emit(PostError(message: 'Ошибка добавления комментария: $e'));
    }
  }

  // delete a comment from a post
  Future<void> deleteComment(String postId, String commentId) async {
    try {
      await postRepo.deleteComment(postId, commentId);

      await fetchAllPosts();
    } catch (e) {
      emit(PostError(message: 'Ошибка удаления комментария: $e'));
    }
  }
}

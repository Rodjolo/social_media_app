import 'package:pocketbase/pocketbase.dart';
import 'package:socail_media_app/config/backend_config.dart';
import 'package:socail_media_app/config/pocketbase_client.dart';
import 'package:socail_media_app/features/post/domain/enteties/comment.dart';
import 'package:socail_media_app/features/post/domain/enteties/post.dart';
import 'package:socail_media_app/features/post/domain/repos/post_repo.dart';

class PocketBasePostRepo implements PostRepo {
  @override
  Future<void> createPost(Post post) async {
    try {
      final pb = await PocketBaseClient.getInstance();
      await pb.collection(BackendConfig.postsCollection).create(
            body: post.toJson(),
          );
    } on ClientException catch (e) {
      throw Exception(e.response['message'] ?? 'Failed to create post');
    } catch (e) {
      throw Exception('Failed to create post: $e');
    }
  }

  @override
  Future<void> deletePost(String postId) async {
    try {
      final pb = await PocketBaseClient.getInstance();
      await pb.collection(BackendConfig.postsCollection).delete(postId);
    } on ClientException catch (e) {
      throw Exception(e.response['message'] ?? 'Failed to delete post');
    } catch (e) {
      throw Exception('Failed to delete post: $e');
    }
  }

  @override
  Future<List<Post>> fetchAllPosts() async {
    try {
      final pb = await PocketBaseClient.getInstance();
      final result =
          await pb.collection(BackendConfig.postsCollection).getFullList(
                sort: '-timestamp',
              );

      return result.map(_mapRecordToPost).toList();
    } on ClientException catch (e) {
      throw Exception(e.response['message'] ?? 'Failed to fetch posts');
    } catch (e) {
      throw Exception('Failed to fetch posts: $e');
    }
  }

  @override
  Future<List<Post>> fetchPostsByUserId(String userId) async {
    try {
      final pb = await PocketBaseClient.getInstance();
      final result =
          await pb.collection(BackendConfig.postsCollection).getFullList(
                filter: 'userId = "$userId"',
                sort: '-timestamp',
              );

      return result.map(_mapRecordToPost).toList();
    } on ClientException catch (e) {
      throw Exception(e.response['message'] ?? 'Failed to fetch posts by user');
    } catch (e) {
      throw Exception('Failed to fetch posts by user: $e');
    }
  }

  @override
  Future<void> toggleLikePost(String postId, String userId) async {
    final pb = await PocketBaseClient.getInstance();
    final record =
        await pb.collection(BackendConfig.postsCollection).getOne(postId);
    final likes = List<String>.from(record.get<List<dynamic>>('likes'));

    if (likes.contains(userId)) {
      likes.remove(userId);
    } else {
      likes.add(userId);
    }

    await pb.collection(BackendConfig.postsCollection).update(
      postId,
      body: {'likes': likes},
    );
  }

  @override
  Future<void> addComment(String postId, Comment comment) async {
    final pb = await PocketBaseClient.getInstance();
    final record =
        await pb.collection(BackendConfig.postsCollection).getOne(postId);
    final comments = List<Map<String, dynamic>>.from(
      (record.get<List<dynamic>>('comments')).map(
        (item) => Map<String, dynamic>.from(item as Map),
      ),
    );
    comments.add(comment.toJson());

    await pb.collection(BackendConfig.postsCollection).update(
      postId,
      body: {'comments': comments},
    );
  }

  @override
  Future<void> deleteComment(String postId, String commentId) async {
    final pb = await PocketBaseClient.getInstance();
    final record =
        await pb.collection(BackendConfig.postsCollection).getOne(postId);
    final comments = List<Map<String, dynamic>>.from(
      (record.get<List<dynamic>>('comments')).map(
        (item) => Map<String, dynamic>.from(item as Map),
      ),
    )..removeWhere((comment) => comment['id']?.toString() == commentId);

    await pb.collection(BackendConfig.postsCollection).update(
      postId,
      body: {'comments': comments},
    );
  }

  Post _mapRecordToPost(RecordModel record) {
    return Post.fromJson({
      'id': record.id,
      ...record.toJson(),
    });
  }
}

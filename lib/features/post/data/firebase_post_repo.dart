import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:socail_media_app/features/post/domain/enteties/comment.dart';
import 'package:socail_media_app/features/post/domain/enteties/post.dart';
import 'package:socail_media_app/features/post/domain/repos/post_repo.dart';

class FirebasePostRepo implements PostRepo {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  final CollectionReference postsCollection =
      FirebaseFirestore.instance.collection('posts');

  @override
  Future<void> createPost(Post post) async {
    try {
      await postsCollection.doc(post.id).set(post.toJson());
    } catch (e) {
      throw Exception('Ошибка создания поста: $e');
    }
  }

  @override
  Future<void> deletePost(String postId) async {
    try {
      await postsCollection.doc(postId).delete();
    } catch (e) {
      throw Exception('Ошибка удаления поста: $e');
    }
  }

  @override
  Future<List<Post>> fetchAllPosts() async {
    try {
      final postsSnapshot =
          await postsCollection.orderBy('timestamp', descending: true).get();

      final List<Post> allPosts = postsSnapshot.docs
          .map((doc) => Post.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
      return allPosts;
    } catch (e) {
      throw Exception('Ошибка получения поста: $e');
    }
  }

  @override
  Future<List<Post>> fetchPostsByUserId(String userId) async {
    try {
      final postsSnapshot =
          await postsCollection.where('userId', isEqualTo: userId).get();

      final List<Post> userPosts = postsSnapshot.docs
          .map((doc) => Post.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
      return userPosts;
    } catch (e) {
      throw Exception('Ошибка получения поста пользователя: $e');
    }
  }

  @override
  Future<void> toggleLikePost(String postId, String userId) async {
    try {
      final postDoc = await postsCollection.doc(postId).get();

      if (postDoc.exists) {
        final post = Post.fromJson(postDoc.data() as Map<String, dynamic>);

        final hasLiked = post.likes.contains(userId);

        if (hasLiked) {
          post.likes.remove(userId); // unlike
        } else {
          post.likes.add(userId); // like
        }

        await postsCollection.doc(postId).update({
          'likes': post.likes,
        });
      } else {
        throw Exception('Пост не найден');
      }
    } catch (e) {
      throw Exception('Ошибка. Ваш лайк не учтён');
    }
  }

  @override
  Future<void> addComment(String postId, Comment comment) async {
    try {
      // get post doc
      final postDoc = await postsCollection.doc(postId).get();

      if (postDoc.exists) {
        // convert json to post
        final post = Post.fromJson(postDoc.data() as Map<String, dynamic>);

        // add new comment
        post.comments.add(comment);

        // update the post document in firestore
        await postsCollection.doc(postId).update({
          'comments': post.comments.map((comment) => comment.toJson()).toList(),
        });
      } else {
        throw Exception('Пост не найден');
      }
    } catch (e) {
      throw Exception('Ошибка добавления комментария: $e');
    }
  }

  @override
  Future<void> deleteComment(String postId, String commentId) async {
    try {
      // get post doc
      final postDoc = await postsCollection.doc(postId).get();

      if (postDoc.exists) {
        // convert json to post
        final post = Post.fromJson(postDoc.data() as Map<String, dynamic>);

        // add new comment
        post.comments.removeWhere((comment) => commentId == comment.id);

        // update the post document in firestore
        await postsCollection.doc(postId).update({
          'comments': post.comments.map((comment) => comment.toJson()).toList(),
        });
      } else {
        throw Exception('Пост не найден');
      }
    } catch (e) {
      throw Exception('Ошибка удаления комментария: $e');
    }
  }
}

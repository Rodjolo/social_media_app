import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:socail_media_app/features/post/domain/enteties/comment.dart';

class Post {
  final String id;
  final String userId;
  final String userName;
  final String text;
  final String imageUrl;
  final DateTime timestamp;
  final List<String> likes; // collections of uid's
  final List<Comment> comments;

  Post({
    required this.id,
    required this.userId,
    required this.userName,
    required this.text,
    this.imageUrl = '',
    required this.timestamp,
    required this.likes,
    required this.comments,
  });

  Post copyWith({
    String? imageUrl,
    List<String>? likes,
    List<Comment>? comments,
  }) {
    return Post(
      id: id,
      userId: userId,
      userName: userName,
      text: text,
      imageUrl: imageUrl ?? this.imageUrl,
      timestamp: timestamp,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'text': text,
      'imageUrl': imageUrl,
      'timestamp': Timestamp.fromDate(timestamp),
      'likes': likes,
      'comments': comments.map((comment) => comment.toJson()).toList(),
    };
  }

  factory Post.fromJson(Map<String, dynamic> json) {
    // prepare comments
    final commentsList = json['comments'] as List<dynamic>? ?? [];
    final List<Comment> comments = commentsList
        .map((comment) => Comment.fromJson(comment as Map<String, dynamic>))
        .toList();

    return Post(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      userName: json['userName']?.toString() ?? 'Unknown User',
      text: json['text']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      timestamp: (json['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likes: List<String>.from(json['likes'] ?? []),
      comments: comments,
    );
  }
}

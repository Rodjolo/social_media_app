import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String id;
  final String postId;
  final String userId;
  final String userName;
  final String text;
  final DateTime timestamp;

  Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    required this.text,
    required this.timestamp,
  });

  // convert comment to json
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'postId': postId,
      'userId': userId,
      'userName': userName,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  // convert json to comment
  factory Comment.fromJson(Map<String, dynamic> json) {
    final rawTimestamp = json['timestamp'];

    return Comment(
      id: json['id'] as String,
      postId: json['postId'] as String,
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      text: json['text'] as String,
      timestamp: rawTimestamp is Timestamp
          ? rawTimestamp.toDate()
          : DateTime.tryParse(rawTimestamp?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

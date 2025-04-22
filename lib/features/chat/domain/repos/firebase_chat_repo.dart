import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:socail_media_app/features/chat/domain/entities/message.dart';
import 'package:socail_media_app/features/chat/domain/repos/chat_repo.dart';

class FirebaseChatRepo implements ChatRepo {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<void> sendMessage(Message message) async {
    await _firestore
        .collection('chats')
        .doc(message.chatId)
        .collection('messages')
        .doc(message.id)
        .set(message.toJson());
    
    // Update last message in chat
    await _firestore.collection('chats').doc(message.chatId).update({
      'lastMessage': message.text,
      'lastMessageTime': message.timestamp,
      'unreadCount': FieldValue.increment(1),
    });
  }

  @override
  Stream<List<Message>> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Message.fromJson(doc.data()))
            .toList());
  }

  @override
  Future<String> getOrCreateChatId(String userId1, String userId2) async {
    final users = [userId1, userId2]..sort();
    final chatId = '${users[0]}_${users[1]}';
    
    final doc = await _firestore.collection('chats').doc(chatId).get();
    
    if (!doc.exists) {
      await _firestore.collection('chats').doc(chatId).set({
        'participants': users,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount': 0,
      });
    }
    
    return chatId;
  }

  @override
  Stream<List<Map<String, dynamic>>> getUserChats(String userId) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'chatId': doc.id,
                'lastMessage': data['lastMessage'],
                'timestamp': data['lastMessageTime'],
                'unreadCount': data['unreadCount'],
                'participants': data['participants'],
              };
            }).toList());
  }

  @override
  Future<void> markMessagesAsRead(String chatId, String userId) async {
    final messages = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('senderId', isNotEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (final doc in messages.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();

    await _firestore.collection('chats').doc(chatId).update({
      'unreadCount': FieldValue.increment(-messages.docs.length),
    });
  }
}
import 'package:socail_media_app/features/chat/domain/entities/message.dart';

abstract class ChatRepo {
  Future<void> sendMessage(Message message);
  Stream<List<Message>> getMessages(String chatId);
  Future<String> getOrCreateChatId(String userId1, String userId2);
  Stream<List<Map<String, dynamic>>> getUserChats(String userId);
  Future<void> markMessagesAsRead(String chatId, String userId);
}
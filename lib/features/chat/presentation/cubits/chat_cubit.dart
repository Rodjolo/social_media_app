import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:socail_media_app/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:socail_media_app/features/chat/domain/entities/message.dart';
import 'package:socail_media_app/features/chat/domain/repos/chat_repo.dart';

part 'chat_state.dart';

class ChatCubit extends Cubit<ChatState> {
  final ChatRepo chatRepo;
  final AuthCubit _authCubit;

  ChatCubit({required this.chatRepo, required AuthCubit authCubit})
      : _authCubit = authCubit,
        super(ChatInitial());

  Future<void> sendMessage(Message message) async {
    try {
      await chatRepo.sendMessage(message);
    } catch (e) {
      emit(ChatError(message: 'Ошибка отправки сообщения: $e'));
    }
  }

  Stream<List<Message>> getMessages(String chatId) {
    return chatRepo.getMessages(chatId);
  }

  Stream<List<Map<String, dynamic>>> getUserChatsStream(String userId) {
    return chatRepo.getUserChats(userId);
  }

  Future<void> markAsRead(String chatId, String userId) async {
    try {
      await chatRepo.markMessagesAsRead(chatId, userId);
    } catch (e) {
      emit(ChatError(message: 'Ошибка отметки сообщений: $e'));
    }
  }

  Future<String> createNewChat(String otherUserId) async {
    try {
      final currentUserId = _authCubit.currentUser!.uid;
      return await chatRepo.getOrCreateChatId(currentUserId, otherUserId);
    } catch (e) {
      emit(ChatError(message: 'Ошибка создания чата: $e'));
      rethrow;
    }
  }
}

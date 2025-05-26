import 'dart:io';
import 'dart:typed_data';

import 'package:socail_media_app/features/storage/domain/storage_repo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseStorageRepo implements StorageRepo {
  final SupabaseStorageClient storage = Supabase.instance.client.storage;

  // mobile
  @override
  Future<String?> uploadProfileImageMobile(String path, String fileName) {
    return _uploadFile(path, fileName, 'profile_images');
  }

  // web
  @override
  Future<String?> uploadProfileImageWeb(Uint8List fileBytes, String fileName) {
    return _uploadFileBytes(fileBytes, fileName, 'profile_images');
  }

  Future<String?> _uploadFile(
      String path, String fileName, String folder) async {
    try {
      final file = File(path);
      final uploadResponse = await storage.from(folder).upload(
            fileName, // Полный путь к файлу
            file,

            fileOptions: const FileOptions(
              upsert: true, // Перезаписать файл при совпадении имени
            ),
          );

      // Проверяем ошибки загрузки
      if (uploadResponse.isEmpty) {
        throw Exception('Ошибка загрузки файла');
      }

      // Получаем публичную ссылку
      final publicUrlResponse = storage.from(folder).getPublicUrl(fileName);
      return publicUrlResponse;
    } catch (e) {
      print('Ошибка загрузки файла: $e');
      return '';
    }
  }

  Future<String?> _uploadFileBytes(
      Uint8List fileBytes, String fileName, String folder) async {
    try {
      final uploadResponse = await storage.from(folder).uploadBinary(
            fileName, // Используется имя с расширением, например, "1698765432101234.jpg"
            fileBytes,
            fileOptions: FileOptions(
              contentType:
                  _getMimeType(fileName), // MIME-тип определяется по расширению
              upsert: true,
            ),
          );

      if (uploadResponse.isEmpty) {
        throw Exception('Ошибка загрузки файла');
      }

      final publicUrl = storage
          .from(folder)
          .getPublicUrl(fileName); // Убрано лишнее "$folder/"
      return publicUrl;
    } catch (e) {
      print('Ошибка загрузки файла: $e');
      return null;
    }
  }

// Вспомогательная функция для определения MIME-типа
  String _getMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  // mobile
  @override
  Future<String?> uploadPostImageMobile(String path, String fileName) {
    return _uploadFile(path, fileName, 'post_images');
  }

  // web
  @override
  Future<String?> uploadPostImageWeb(Uint8List fileBytes, String fileName) {
    return _uploadFileBytes(fileBytes, fileName, 'post_images');
  }
}

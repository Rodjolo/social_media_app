import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';
import 'package:socail_media_app/config/backend_config.dart';
import 'package:socail_media_app/config/pocketbase_client.dart';
import 'package:socail_media_app/features/storage/domain/storage_repo.dart';

class PocketBaseStorageRepo implements StorageRepo {
  @override
  Future<String?> uploadProfileImageMobile(String path, String fileName) {
    return _uploadFile(
      path: path,
      fileName: fileName,
      category: 'profile',
    );
  }

  @override
  Future<String?> uploadProfileImageWeb(Uint8List fileBytes, String fileName) {
    return _uploadBytes(
      fileBytes: fileBytes,
      fileName: fileName,
      category: 'profile',
    );
  }

  @override
  Future<String?> uploadPostImageMobile(String path, String fileName) {
    return _uploadFile(
      path: path,
      fileName: fileName,
      category: 'post',
    );
  }

  @override
  Future<String?> uploadPostImageWeb(Uint8List fileBytes, String fileName) {
    return _uploadBytes(
      fileBytes: fileBytes,
      fileName: fileName,
      category: 'post',
    );
  }

  Future<String?> _uploadFile({
    required String path,
    required String fileName,
    required String category,
  }) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    return _uploadBytes(
      fileBytes: bytes,
      fileName: fileName,
      category: category,
    );
  }

  Future<String?> _uploadBytes({
    required Uint8List fileBytes,
    required String fileName,
    required String category,
  }) async {
    try {
      final pb = await PocketBaseClient.getInstance();
      final ownerId = pb.authStore.record?.id ?? '';

      final record = await pb.collection(BackendConfig.mediaCollection).create(
        body: {
          'ownerId': ownerId,
          'category': category,
        },
        files: [
          http.MultipartFile.fromBytes(
            'file',
            fileBytes,
            filename: fileName,
          ),
        ],
      );

      final storedFileName = record.getStringValue('file');
      if (storedFileName.isEmpty) {
        throw Exception('PocketBase did not return uploaded file name');
      }

      return pb.files.getURL(record, storedFileName).toString();
    } on ClientException catch (e) {
      throw Exception(e.response['message'] ?? 'Failed to upload file');
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
  }
}

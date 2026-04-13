import 'package:pocketbase/pocketbase.dart';
import 'package:socail_media_app/config/backend_config.dart';
import 'package:socail_media_app/config/pocketbase_client.dart';
import 'package:socail_media_app/features/auth/domain/entities/app_user.dart';
import 'package:socail_media_app/features/auth/domain/repos/auth_repo.dart';

class PocketBaseAuthRepo implements AuthRepo {
  @override
  Future<AppUser?> loginWithEmailPassword(String email, String password) async {
    try {
      final pb = await PocketBaseClient.getInstance();
      final authData =
          await pb.collection(BackendConfig.usersCollection).authWithPassword(
                email,
                password,
              );

      return _mapRecordToUser(authData.record);
    } on ClientException catch (e) {
      throw Exception(e.response['message'] ?? 'PocketBase login failed');
    } catch (e) {
      throw Exception('PocketBase login failed: $e');
    }
  }

  @override
  Future<AppUser?> registerWithEmailPassword(
    String name,
    String email,
    String password,
  ) async {
    try {
      final pb = await PocketBaseClient.getInstance();

      await pb.collection(BackendConfig.usersCollection).create(
        body: {
          'email': email,
          'password': password,
          'passwordConfirm': password,
          'name': name,
          'bio': '',
          'profileImageUrl': '',
          'followers': <String>[],
          'following': <String>[],
          'favoriteGenres': <String>[],
          'movieOnboardingCompleted': false,
        },
      );

      final authData =
          await pb.collection(BackendConfig.usersCollection).authWithPassword(
                email,
                password,
              );

      return _mapRecordToUser(authData.record);
    } on ClientException catch (e) {
      throw Exception(
          e.response['message'] ?? 'PocketBase registration failed');
    } catch (e) {
      throw Exception('PocketBase registration failed: $e');
    }
  }

  @override
  Future<void> logout() async {
    final pb = await PocketBaseClient.getInstance();
    pb.authStore.clear();
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    final pb = await PocketBaseClient.getInstance();
    final record = pb.authStore.record;

    if (record == null) {
      return null;
    }

    try {
      if (pb.authStore.isValid) {
        await pb.collection(BackendConfig.usersCollection).authRefresh();
        return _mapRecordToUser(pb.authStore.record);
      }
    } catch (_) {
      pb.authStore.clear();
      return null;
    }

    pb.authStore.clear();
    return null;
  }

  AppUser? _mapRecordToUser(RecordModel? record) {
    if (record == null) {
      return null;
    }

    return AppUser(
      uid: record.id,
      email: record.getStringValue('email'),
      name: record.getStringValue('name'),
    );
  }
}

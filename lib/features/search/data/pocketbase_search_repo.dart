import 'package:socail_media_app/config/backend_config.dart';
import 'package:socail_media_app/config/pocketbase_client.dart';
import 'package:socail_media_app/features/profile/domain/entities/profile_user.dart';
import 'package:socail_media_app/features/search/domain/search_repo.dart';

class PocketBaseSearchRepo implements SearchRepo {
  @override
  Future<List<ProfileUser?>> searchUsers(String query) async {
    try {
      final pb = await PocketBaseClient.getInstance();
      final result = await pb.collection(BackendConfig.usersCollection).getList(
            page: 1,
            perPage: 20,
            filter: 'name ~ "${query.replaceAll('"', '\\"')}"',
          );

      return result.items.map((record) {
        final storedProfileImageUrl = record.getStringValue('profileImageUrl');
        final fileName = record.getStringValue('profileImage');
        final profileImageUrl = storedProfileImageUrl.isNotEmpty
            ? storedProfileImageUrl
            : (fileName.isNotEmpty
                ? pb.files.getURL(record, fileName).toString()
                : '');

        return ProfileUser(
          uid: record.id,
          email: record.getStringValue('email'),
          name: record.getStringValue('name'),
          isAdmin: record.getBoolValue('isAdmin'),
          bio: record.getStringValue('bio'),
          profileImageUrl: profileImageUrl,
          followers: List<String>.from(record.get<List<dynamic>>('followers')),
          following: List<String>.from(record.get<List<dynamic>>('following')),
        );
      }).toList();
    } catch (e) {
      throw Exception('Search failed: $e');
    }
  }
}

import 'package:pocketbase/pocketbase.dart';
import 'package:socail_media_app/config/backend_config.dart';
import 'package:socail_media_app/config/pocketbase_client.dart';
import 'package:socail_media_app/features/profile/domain/entities/profile_user.dart';
import 'package:socail_media_app/features/profile/domain/repos/profile_repo.dart';

class PocketBaseProfileRepo implements ProfileRepo {
  @override
  Future<ProfileUser?> fetchUserProfile(String uid) async {
    try {
      final pb = await PocketBaseClient.getInstance();
      final record =
          await pb.collection(BackendConfig.usersCollection).getOne(uid);
      return _mapRecordToProfileUser(pb, record);
    } on ClientException {
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> updateProfile(ProfileUser updatedProfile) async {
    try {
      final pb = await PocketBaseClient.getInstance();
      await pb.collection(BackendConfig.usersCollection).update(
        updatedProfile.uid,
        body: {
          'name': updatedProfile.name,
          'bio': updatedProfile.bio,
          'profileImageUrl': updatedProfile.profileImageUrl,
          'followers': updatedProfile.followers,
          'following': updatedProfile.following,
        },
      );
    } on ClientException catch (e) {
      throw Exception(e.response['message'] ?? 'Failed to update profile');
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  @override
  Future<void> toggleFollow(String currentUid, String targetUid) async {
    final pb = await PocketBaseClient.getInstance();
    final currentRecord =
        await pb.collection(BackendConfig.usersCollection).getOne(currentUid);
    final targetRecord =
        await pb.collection(BackendConfig.usersCollection).getOne(targetUid);

    final currentFollowing =
        List<String>.from(currentRecord.get<List<dynamic>>('following'));
    final targetFollowers =
        List<String>.from(targetRecord.get<List<dynamic>>('followers'));

    final isFollowing = currentFollowing.contains(targetUid);

    if (isFollowing) {
      currentFollowing.remove(targetUid);
      targetFollowers.remove(currentUid);
    } else {
      currentFollowing.add(targetUid);
      targetFollowers.add(currentUid);
    }

    await pb.collection(BackendConfig.usersCollection).update(
      currentUid,
      body: {'following': currentFollowing},
    );
    await pb.collection(BackendConfig.usersCollection).update(
      targetUid,
      body: {'followers': targetFollowers},
    );
  }

  ProfileUser _mapRecordToProfileUser(PocketBase pb, RecordModel record) {
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
  }
}

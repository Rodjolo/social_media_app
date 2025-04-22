import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:socail_media_app/features/profile/domain/entities/profile_user.dart';
import 'package:socail_media_app/features/profile/domain/repos/profile_repo.dart';
import 'package:socail_media_app/features/profile/presentation/cubit/profile_states.dart';
import 'package:socail_media_app/features/storage/domain/storage_repo.dart';

class ProfileCubit extends Cubit<ProfileState> {
  final ProfileRepo profileRepo;
  final StorageRepo storageRepo;

  ProfileCubit({required this.storageRepo, required this.profileRepo})
      : super(ProfileInitial());

  Future<void> fetchUserProfile(String uid) async {
    try {
      emit(ProfileLoading());
      final user = await profileRepo.fetchUserProfile(uid);

      if (user != null) {
        emit(ProfileLoaded(user));
      } else {
        emit(ProfileError('Пользователь не найден'));
      }
    } catch (e) {
      emit(ProfileError(e.toString()));
    }
  }

  Future<ProfileUser?> getUserProfile(String uid) async {
    final user = await profileRepo.fetchUserProfile(uid);
    return user;
  }

  Future<void> updateProfile({
    required String uid,
    String? newBio,
    Uint8List? imageWebBytes,
    String? imageMobilePath,
  }) async {
    emit(ProfileLoading());

    try {
      final currentUser = await profileRepo.fetchUserProfile(uid);
      if (currentUser == null) {
        emit(ProfileError('Пользователь не найден'));
        return;
      }

      String? imageDownloadUrl;

      if (imageWebBytes != null || imageMobilePath != null) {
        imageDownloadUrl = imageMobilePath != null
            ? await storageRepo.uploadProfileImageMobile(imageMobilePath, uid)
            : await storageRepo.uploadProfileImageWeb(imageWebBytes!, uid);

        if (imageDownloadUrl == null) {
          emit(ProfileError('Ошибка загрузки изображения'));
          return;
        }

        imageDownloadUrl += "?t=${DateTime.now().millisecondsSinceEpoch}";
      }

      final updatedProfile = currentUser.copyWith(
        newBio: newBio ?? currentUser.bio,
        newProfileImageUrl: imageDownloadUrl,
      );

      await profileRepo.updateProfile(updatedProfile);

      emit(ProfileLoaded(updatedProfile));
      await fetchUserProfile(uid);
    } catch (e) {
      emit(ProfileError('Ошибка обновления: ${e.toString()}'));
    }
  }

  // toggle follow / unfollow
  Future<void> toggleFollow(String currentUserId, String targetUserId) async {
    try {
      await profileRepo.toggleFollow(currentUserId, targetUserId);
    } catch (e) {
      emit(ProfileError('Ошибка подписки: $e'));
    }
  }
}

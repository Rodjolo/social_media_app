import 'package:socail_media_app/features/profile/domain/entities/profile_user.dart';

abstract class SearchState{}

class SerachInitial extends SearchState{}

class SearchLoading extends SearchState{}

class SearchLoaded extends SearchState{
  final List<ProfileUser?> users;

  SearchLoaded(this.users);
}

class SearchError extends SearchState{
  final String message;

  SearchError(this.message);
}
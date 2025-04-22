import '../../domain/enteties/post.dart';

abstract class PostState {}

class PostInitial extends PostState {}

class PostLoading extends PostState {}

class PostUploading extends PostState {}

class PostError extends PostState {
  final String message;
  PostError({required this.message});
}

class PostLoaded extends PostState {
  final List<Post> posts;
  PostLoaded({required this.posts});
}

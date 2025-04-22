import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:socail_media_app/features/search/domain/search_repo.dart';
import 'package:socail_media_app/features/search/presentation/cubits/search_states.dart';

class SearchCubit extends Cubit<SearchState> {
  final SearchRepo searchRepo;

  SearchCubit({required this.searchRepo}) : super(SerachInitial());

  Future<void> searchUsers(String query) async {
    if (query.isEmpty) {
      emit(SerachInitial());
      return;
    }

    try {
      emit(SearchLoading());
      final users = await searchRepo.searchUsers(query);
      emit(SearchLoaded(users));
    } catch (e) {
      emit(SearchError('Ошибка обновления результатов поиска'));
    }
  }
}

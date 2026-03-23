import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socail_media_app/config/backend_config.dart';

class PocketBaseClient {
  PocketBaseClient._();

  static PocketBase? _instance;
  static AsyncAuthStore? _authStore;

  static Future<PocketBase> getInstance() async {
    if (_instance != null) {
      return _instance!;
    }

    final preferences = await SharedPreferences.getInstance();
    _authStore = AsyncAuthStore(
      save: (String data) async => preferences.setString('pb_auth', data),
      initial: preferences.getString('pb_auth'),
      clear: () async => preferences.remove('pb_auth'),
    );

    _instance = PocketBase(
      BackendConfig.pocketBaseUrl,
      authStore: _authStore,
    );

    return _instance!;
  }
}

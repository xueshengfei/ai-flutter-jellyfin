import 'package:jellyfin_service/src/jellyfin_client.dart';
import 'package:jellyfin_service/src/models/user_models.dart';

/// 封装已认证的 [JellyfinClient] + [UserProfile] 会话信息
class AppSession {
  final JellyfinClient client;
  final UserProfile user;

  const AppSession({required this.client, required this.user});

  String get serverUrl => client.configuration.serverUrl;
  String? get accessToken => client.configuration.accessToken;
}

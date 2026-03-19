import 'package:equatable/equatable.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart' as jellyfin_dart;

/// 用户配置信息
///
/// 包含用户的基本配置和偏好设置
class UserProfile extends Equatable {
  /// 用户ID
  final String id;

  /// 用户名
  final String name;

  /// 服务器URL
  final String serverUrl;

  /// 主图片标签（用于头像）
  final String? primaryImageTag;

  /// 最后登录日期
  final DateTime? lastLoginDate;

  /// 是否是管理员
  final bool isAdmin;

  const UserProfile({
    required this.id,
    required this.name,
    required this.serverUrl,
    this.primaryImageTag,
    this.lastLoginDate,
    this.isAdmin = false,
  });

  /// 从jellyfin_dart的UserDto创建UserProfile
  factory UserProfile.fromDto(jellyfin_dart.UserDto dto) {
    return UserProfile(
      id: dto.id ?? '',
      name: dto.name ?? '',
      serverUrl: '', // 由外部设置
      primaryImageTag: dto.primaryImageTag,
      lastLoginDate: dto.lastLoginDate,
      isAdmin: dto.policy?.isAdministrator == true,
    );
  }

  /// 获取头像图片URL
  String? getPrimaryImageUrl(String baseUrl) {
    if (primaryImageTag == null) return null;
    return '$baseUrl/Users/$id/Images/Primary?$primaryImageTag';
  }

  @override
  List<Object?> get props => [id, name, serverUrl, primaryImageTag, isAdmin];

  @override
  String toString() {
    return 'UserProfile(id: $id, name: $name, isAdmin: $isAdmin)';
  }
}

/// 认证结果
///
/// 包含访问令牌和用户信息
class AuthenticationResult extends Equatable {
  /// 访问令牌
  final String accessToken;

  /// 用户信息
  final UserProfile user;

  /// 服务器ID
  final String? serverId;

  /// 会话信息
  final SessionInfo? sessionInfo;

  const AuthenticationResult({
    required this.accessToken,
    required this.user,
    this.serverId,
    this.sessionInfo,
  });

  @override
  List<Object?> get props => [accessToken, user, serverId];

  @override
  String toString() {
    return 'AuthenticationResult(user: ${user.name}, serverId: $serverId)';
  }
}

/// 会话信息
class SessionInfo extends Equatable {
  /// 播放会话ID
  final String? playSessionId;

  /// 用户ID
  final String? userId;

  /// 用户名
  final String? username;

  /// 服务器ID
  final String? serverId;

  const SessionInfo({
    this.playSessionId,
    this.userId,
    this.username,
    this.serverId,
  });

  @override
  List<Object?> get props => [playSessionId, userId, username, serverId];

  @override
  String toString() {
    return 'SessionInfo(playSessionId: $playSessionId, userId: $userId)';
  }
}

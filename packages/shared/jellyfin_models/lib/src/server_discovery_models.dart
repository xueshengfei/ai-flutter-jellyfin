import 'package:equatable/equatable.dart';

/// 发现的 Jellyfin 服务器信息
class DiscoveredServer extends Equatable {
  /// 服务器唯一 ID
  final String id;

  /// 服务器名称
  final String name;

  /// 服务器地址
  final String address;

  /// 端点地址
  final String? endpointAddress;

  /// 服务器版本
  final String? version;

  /// 服务器局域网地址
  final String? localAddress;

  /// 是否已完成初始设置向导
  final bool? startupWizardCompleted;

  const DiscoveredServer({
    required this.id,
    required this.name,
    required this.address,
    this.endpointAddress,
    this.version,
    this.localAddress,
    this.startupWizardCompleted,
  });

  /// 从 UDP 广播响应 JSON 创建
  factory DiscoveredServer.fromJson(Map<String, dynamic> json) {
    return DiscoveredServer(
      id: json['Id'] as String? ?? '',
      name: json['Name'] as String? ?? 'Unknown',
      address: json['Address'] as String? ?? '',
      endpointAddress: json['EndpointAddress'] as String?,
    );
  }

  /// 从 GET /System/Info/Public 响应创建
  factory DiscoveredServer.fromPublicInfo(
    Map<String, dynamic> json,
    String requestAddress,
  ) {
    return DiscoveredServer(
      id: json['Id'] as String? ?? '',
      name: json['ServerName'] as String? ?? '',
      address: requestAddress,
      version: json['Version'] as String?,
      localAddress: json['LocalAddress'] as String?,
      startupWizardCompleted: json['StartupWizardCompleted'] as bool?,
    );
  }

  /// 合并 UDP 发现结果与 PublicInfo 验证结果
  DiscoveredServer mergeWith(DiscoveredServer other) {
    return DiscoveredServer(
      id: other.id.isNotEmpty ? other.id : id,
      name: other.name.isNotEmpty ? other.name : name,
      address: other.address.isNotEmpty ? other.address : address,
      endpointAddress: other.endpointAddress ?? endpointAddress,
      version: other.version ?? version,
      localAddress: other.localAddress ?? localAddress,
      startupWizardCompleted: other.startupWizardCompleted ?? startupWizardCompleted,
    );
  }

  @override
  List<Object?> get props =>
      [id, name, address, endpointAddress, version, localAddress];

  @override
  String toString() =>
      'DiscoveredServer(name: $name, address: $address, version: $version)';
}

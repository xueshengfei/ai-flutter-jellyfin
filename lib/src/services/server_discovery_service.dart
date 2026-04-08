import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import '../models/server_discovery_models.dart';

/// 服务器发现服务
///
/// 通过 UDP 广播自动发现局域网内的 Jellyfin 服务器。
/// 不依赖 ApiClient，独立工作（发现阶段还没有服务器地址）。
///
/// 参照 jellyfin-web 的 ConnectionManager 实现：
/// - [discoverServers] 对应 NativeShell.findServers (UDP 广播)
/// - [verifyServer] 对应 tryConnect (GET /System/Info/Public)
/// - [connectToAddress] 对应手动输入地址连接（自动补全协议前缀）
class ServerDiscoveryService {
  final Logger _logger;

  ServerDiscoveryService({Logger? logger}) : _logger = logger ?? Logger();

  /// 通过 UDP 广播发现局域网内的 Jellyfin 服务器
  ///
  /// 向 255.255.255.255:7359 发送 "who is JellyfinServer?"
  /// 超时 [timeout]（默认 3 秒）后返回收到的所有响应（按 Id 去重）
  Future<List<DiscoveredServer>> discoverServers({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final discovered = <String, DiscoveredServer>{};

    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      try {
        socket.broadcastEnabled = true;
        socket.multicastLoopback = true;

        final message = utf8.encode('who is JellyfinServer?');
        socket.send(message, InternetAddress('255.255.255.255'), 7359);

        final deadline = DateTime.now().add(timeout);

        await for (final event in socket.timeout(
          timeout,
          onTimeout: (sink) => sink.close(),
        )) {
          if (DateTime.now().isAfter(deadline)) break;
          if (event == RawSocketEvent.read) {
            final datagram = socket.receive();
            if (datagram == null) continue;

            try {
              final jsonStr = utf8.decode(datagram.data);
              final json = jsonDecode(jsonStr) as Map<String, dynamic>;
              final server = DiscoveredServer.fromJson(json);
              if (server.id.isNotEmpty && server.address.isNotEmpty) {
                discovered[server.id] = server;
                _logger.d('发现服务器: ${server.name} @ ${server.address}');
              }
            } catch (e) {
              _logger.w('解析服务器响应失败: $e');
            }
          }
        }
      } finally {
        socket.close();
      }
    } catch (e) {
      _logger.w('UDP 广播失败: $e');
    }

    return discovered.values.toList();
  }

  /// 验证服务器是否可达并获取公开信息
  ///
  /// 调用 GET /System/Info/Public（无需认证）。
  /// 返回包含版本等详细信息的 DiscoveredServer，失败返回 null。
  Future<DiscoveredServer?> verifyServer(String address) async {
    final url = _buildUrl(address, 'System/Info/Public');
    try {
      final dio = Dio();
      final response = await dio.get<Map<String, dynamic>>(url);

      if (response.statusCode == 200 && response.data != null) {
        return DiscoveredServer.fromPublicInfo(
          response.data!,
          _normalizeAddress(address),
        );
      }
    } catch (e) {
      _logger.w('验证服务器 $address 失败: $e');
    }
    return null;
  }

  /// 手动输入地址连接（对应 jellyfin-web 的 connectToAddress）
  ///
  /// 如果地址不包含协议前缀，依次尝试 https:// 和 http://
  /// 连接成功返回带版本等详情的服务器信息，失败返回 null
  Future<DiscoveredServer?> connectToAddress(String host) async {
    final trimmed = host.replaceFirst(RegExp(r'/+$'), '');

    // 已经有协议前缀，直接尝试
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return verifyServer(trimmed);
    }

    // 无协议前缀：先尝试 https，再尝试 http（与 jellyfin-web 一致）
    for (final scheme in ['https://', 'http://']) {
      final result = await verifyServer('$scheme$trimmed');
      if (result != null) return result;
    }
    return null;
  }

  String _buildUrl(String base, String path) {
    final b = base.replaceFirst(RegExp(r'/+$'), '');
    return '$b/$path';
  }

  String _normalizeAddress(String address) {
    return address.replaceFirst(RegExp(r'/+$'), '');
  }
}

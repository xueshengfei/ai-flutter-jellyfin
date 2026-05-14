import 'dart:convert';
import 'dart:io';

import '../models/discovered_server.dart';

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
              }
            } catch (_) {
              // 忽略解析失败的响应
            }
          }
        }
      } finally {
        socket.close();
      }
    } catch (_) {
      // UDP 广播失败（如无网络权限），静默处理
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
      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse(url));
        final response = await request.close();
        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          final json = jsonDecode(body) as Map<String, dynamic>;
          return DiscoveredServer.fromPublicInfo(
            json,
            _normalizeAddress(address),
          );
        }
      } finally {
        client.close();
      }
    } catch (_) {
      // 验证失败，静默处理
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

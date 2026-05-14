import 'package:flutter/material.dart';

import '../models/discovered_server.dart';
import '../services/server_discovery_service.dart';

/// 登录页面
///
/// 纯 UI 组件，认证能力通过 [onLogin] 回调注入。
/// 不依赖任何具体的服务端实现。
///
/// 可选注入 [discoveryService] 启用局域网服务器自动发现。
class LoginPage extends StatefulWidget {
  /// 登录回调，返回 null 表示成功，返回错误信息字符串表示失败
  final Future<String?> Function({
    required String serverUrl,
    required String username,
    required String password,
  }) onLogin;

  /// 默认服务器地址
  final String defaultServerUrl;

  /// 默认用户名
  final String defaultUsername;

  /// 默认密码
  final String defaultPassword;

  /// 可选：局域网服务器发现服务，传入后自动扫描
  final ServerDiscoveryService? discoveryService;

  const LoginPage({
    super.key,
    required this.onLogin,
    this.defaultServerUrl = 'http://localhost:8096',
    this.defaultUsername = 'xue13',
    this.defaultPassword = '123456',
    this.discoveryService,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final _serverController = TextEditingController(text: widget.defaultServerUrl);
  late final _usernameController = TextEditingController(text: widget.defaultUsername);
  late final _passwordController = TextEditingController(text: widget.defaultPassword);
  bool _isLoading = false;
  String? _error;

  // 服务器发现
  List<DiscoveredServer> _discoveredServers = [];
  bool _isDiscovering = false;
  String? _verifyingAddress;

  @override
  void initState() {
    super.initState();
    if (widget.discoveryService != null) {
      _discoverServers();
    }
  }

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _discoverServers() async {
    final service = widget.discoveryService;
    if (service == null) return;

    setState(() {
      _isDiscovering = true;
      _discoveredServers = [];
    });
    try {
      final servers = await service.discoverServers();
      if (mounted) {
        setState(() {
          _discoveredServers = servers;
          _isDiscovering = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isDiscovering = false);
    }
  }

  Future<void> _selectServer(DiscoveredServer server) async {
    _serverController.text = server.address;
    setState(() => _verifyingAddress = server.address);

    final service = widget.discoveryService;
    if (service != null) {
      final verified = await service.verifyServer(server.address);
      if (!mounted) return;

      final updated = verified != null ? server.mergeWith(verified) : server;
      setState(() {
        _verifyingAddress = null;
        final idx = _discoveredServers.indexWhere((s) => s.id == server.id);
        if (idx >= 0) _discoveredServers[idx] = updated;
      });
    } else {
      if (mounted) setState(() => _verifyingAddress = null);
    }
  }

  Future<void> _login() async {
    final serverUrl = _serverController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (serverUrl.isEmpty || username.isEmpty) {
      setState(() => _error = '请输入服务器地址和用户名');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final error = await widget.onLogin(
        serverUrl: serverUrl,
        username: username,
        password: password,
      );
      if (mounted && error != null) {
        setState(() {
          _error = error;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '登录失败: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_circle_filled, size: 72, color: Theme.of(context).primaryColor),
                const SizedBox(height: 24),
                Text('Jellyfin', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 32),
                // 局域网服务器发现区域
                if (widget.discoveryService != null)
                  _buildDiscoverySection(context),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                TextField(
                  controller: _serverController,
                  decoration: const InputDecoration(
                    labelText: '服务器地址',
                    hintText: 'http://192.168.1.100:8096',
                    border: OutlineInputBorder(),
                  ),
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: '用户名',
                    border: OutlineInputBorder(),
                  ),
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: '密码',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  enabled: !_isLoading,
                  onSubmitted: (_) => _login(),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('登录'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDiscoverySection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text('局域网服务器', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            if (_isDiscovering)
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            else
              TextButton.icon(
                onPressed: _discoverServers,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('扫描'),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_isDiscovering)
          const Center(child: Padding(
            padding: EdgeInsets.all(12),
            child: Text('正在扫描局域网...', style: TextStyle(color: Colors.grey)),
          ))
        else if (_discoveredServers.isEmpty)
          const Center(child: Padding(
            padding: EdgeInsets.all(12),
            child: Text('未发现局域网服务器，请手动输入', style: TextStyle(color: Colors.grey)),
          ))
        else
          Column(
            children: _discoveredServers.map((server) {
              final isVerifying = _verifyingAddress == server.address;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: isVerifying ? null : () => _selectServer(server),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: isVerifying
                          ? Border.all(color: colorScheme.primary, width: 1.5)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: colorScheme.primaryContainer,
                          ),
                          child: isVerifying
                              ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                              : const Icon(Icons.dns, size: 22, color: Colors.white70),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(server.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text(server.address, style: TextStyle(fontSize: 12, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
                              if (server.version != null)
                                Text('v${server.version}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: Colors.grey.shade400),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}

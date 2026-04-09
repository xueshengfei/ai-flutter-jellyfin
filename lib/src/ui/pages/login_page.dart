import 'package:flutter/material.dart';
import 'package:jellyfin_service/src/jellyfin_client.dart';
import 'package:jellyfin_service/src/services/server_discovery_service.dart';
import 'package:jellyfin_service/src/models/server_discovery_models.dart';
import 'package:jellyfin_service/src/ui/pages/media_libraries_page.dart';
import 'package:jellyfin_service/src/debug/network_simulator.dart';

/// 登录页面 - 演示 SDK 的最小接入方式
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _serverController = TextEditingController(text: 'http://localhost:8096');
  final _usernameController = TextEditingController(text: 'xue13');
  final _passwordController = TextEditingController(text: '123456');

  String _status = '请登录';
  bool _isLoading = false;

  // 服务器发现
  final _discoveryService = ServerDiscoveryService();
  List<DiscoveredServer> _discoveredServers = [];
  bool _isDiscovering = false;
  String? _verifyingAddress;

  @override
  void initState() {
    super.initState();
    _discoverServers();
  }

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _discoverServers() async {
    setState(() {
      _isDiscovering = true;
      _discoveredServers = [];
    });
    try {
      final servers = await _discoveryService.discoverServers();
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
    setState(() {
      _verifyingAddress = server.address;
      _status = '正在验证服务器...';
    });
    final verified = await _discoveryService.verifyServer(server.address);
    if (!mounted) return;

    // 用 PublicInfo 详情更新列表中的条目
    final updated = verified != null ? server.mergeWith(verified) : server;
    setState(() {
      _verifyingAddress = null;
      final idx = _discoveredServers.indexWhere((s) => s.id == server.id);
      if (idx >= 0) _discoveredServers[idx] = updated;
      if (verified != null) {
        _status = '服务器已验证: ${updated.name}';
      } else {
        _status = '服务器验证失败，请确认地址是否正确';
      }
    });
  }

  Future<void> _login() async {
    if (_serverController.text.isEmpty) {
      setState(() => _status = '请输入服务器地址');
      return;
    }

    setState(() {
      _isLoading = true;
      _status = '正在登录...';
    });

    try {
      final client = JellyfinClient(
        serverUrl: _serverController.text,
        enableLogging: true,
        interceptors: [SlowNetSimulator.instance],
      );

      final result = await client.auth.authenticate(
        username: _usernameController.text,
        password: _passwordController.text,
      );

      setState(() {
        _status = '登录成功! 正在跳转...';
        _isLoading = false;
      });

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MediaLibrariesPage(
              client: client,
              user: result.user,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _status = '登录失败: $e';
        _isLoading = false;
      });
    }
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
                      border: _verifyingAddress == server.address
                          ? Border.all(color: colorScheme.primary, width: 1.5)
                          : null,
                    ),
                    child: Row(
                      children: [
                        // 服务器图标
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
                        // 名称 + 地址 + 版本
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
                        // 点击连接箭头
                        Icon(Icons.chevron_right, color: Colors.grey.shade400),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primaryContainer,
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Card(
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(Icons.movie, size: 64, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 16),
                        Text('Jellyfin Example', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        Text(_status, style: TextStyle(color: _status.contains('失败') ? Colors.red : Colors.grey), textAlign: TextAlign.center),
                        const SizedBox(height: 32),
                        // 服务器发现区域
                        _buildDiscoverySection(context),
                        const SizedBox(height: 12),
                        TextField(controller: _serverController, decoration: const InputDecoration(labelText: '服务器地址', prefixIcon: Icon(Icons.dns), border: OutlineInputBorder())),
                        const SizedBox(height: 16),
                        TextField(controller: _usernameController, decoration: const InputDecoration(labelText: '用户名', prefixIcon: Icon(Icons.person), border: OutlineInputBorder()), textInputAction: TextInputAction.next),
                        const SizedBox(height: 16),
                        TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: '密码', prefixIcon: Icon(Icons.lock), border: OutlineInputBorder()), textInputAction: TextInputAction.done, onSubmitted: (_) => _login()),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _isLoading ? null : _login, style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)), child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('登录', style: TextStyle(fontSize: 16))),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

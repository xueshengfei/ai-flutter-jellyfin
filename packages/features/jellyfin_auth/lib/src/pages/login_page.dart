import 'package:flutter/material.dart';

/// 登录页面
///
/// 纯 UI 组件，认证能力通过 [onLogin] 回调注入。
/// 不依赖任何具体的服务端实现。
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

  const LoginPage({
    super.key,
    required this.onLogin,
    this.defaultServerUrl = 'http://localhost:8096',
    this.defaultUsername = 'xue13',
    this.defaultPassword = '123456',
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

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
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
                const SizedBox(height: 48),
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
}

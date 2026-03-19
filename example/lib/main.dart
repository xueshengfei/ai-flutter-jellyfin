import 'package:flutter/material.dart';
import 'package:jellyfin_service/jellyfin_service.dart';

void main() {
  runApp(const JellyfinTestApp());
}

class JellyfinTestApp extends StatelessWidget {
  const JellyfinTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jellyfin Service 测试',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const TestHomePage(),
    );
  }
}

class TestHomePage extends StatefulWidget {
  const TestHomePage({super.key});

  @override
  State<TestHomePage> createState() => _TestHomePageState();
}

class _TestHomePageState extends State<TestHomePage> {
  final _serverController = TextEditingController(
    text: 'http://localhost:8096',
  );
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  JellyfinClient? _client;
  String _status = '未连接';
  String _userInfo = '';
  bool _isLoading = false;

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_serverController.text.isEmpty) {
      setState(() => _status = '请输入服务器地址');
      return;
    }

    setState(() {
      _isLoading = true;
      _status = '正在连接...';
    });

    try {
      _client = JellyfinClient(
        serverUrl: _serverController.text,
        enableLogging: true,
      );

      setState(() {
        _status = '✅ 已连接到服务器';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = '❌ 连接失败: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _login() async {
    if (_client == null) {
      setState(() => _status = '请先连接服务器');
      return;
    }

    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _status = '请输入用户名和密码');
      return;
    }

    setState(() {
      _isLoading = true;
      _status = '正在登录...';
    });

    try {
      final result = await _client!.auth.authenticate(
        username: _usernameController.text,
        password: _passwordController.text,
      );

      setState(() {
        _status = '✅ 登录成功!';
        _userInfo = '''
用户ID: ${result.user.id}
用户名: ${result.user.name}
管理员: ${result.user.isAdmin ? '是' : '否'}
服务器ID: ${result.serverId ?? 'N/A'}
访问令牌: ${result.accessToken.substring(0, 10)}...
''';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = '❌ 登录失败: $e';
        _userInfo = '';
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    if (_client == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _client!.auth.logout();
      setState(() {
        _status = '✅ 已登出';
        _userInfo = '';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = '❌ 登出失败: $e';
        _isLoading = false;
      });
    }
  }

  void _checkStatus() {
    if (_client == null) {
      setState(() => _status = '未连接');
      return;
    }

    final isAuthenticated = _client!.isAuthenticated;
    setState(() {
      _status = isAuthenticated ? '✅ 已登录' : '✅ 已连接但未登录';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Jellyfin Service 测试'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 状态卡片
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '状态',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(_status),
                    if (_userInfo.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('用户信息:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(_userInfo, style: const TextStyle(fontFamily: 'monospace')),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 服务器连接
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '1. 连接服务器',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _serverController,
                      decoration: const InputDecoration(
                        labelText: '服务器地址',
                        hintText: 'http://localhost:8096',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _isLoading ? null : _connect,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('连接'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 登录
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '2. 用户登录',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: '用户名',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: '密码',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: _isLoading ? null : _login,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('登录'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : _logout,
                            child: const Text('登出'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 检查状态
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '3. 检查状态',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: _isLoading ? null : _checkStatus,
                      child: const Text('检查登录状态'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 说明
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '使用说明',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    const Text('1. 确保你的 Jellyfin 服务器正在运行'),
                    const Text('2. 输入服务器地址（本地: http://localhost:8096）'),
                    const Text('3. 点击"连接"按钮'),
                    const Text('4. 输入用户名和密码'),
                    const Text('5. 点击"登录"按钮'),
                    const Text('6. 查看登录结果和用户信息'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

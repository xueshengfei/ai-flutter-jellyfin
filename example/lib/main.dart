import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:jellyfin_service/jellyfin_service.dart';
import 'jellyfin_image.dart';
import 'media_items_page.dart';

void main() {
  runApp(const JellyfinTestApp());
}

class JellyfinTestApp extends StatelessWidget {
  const JellyfinTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jellyfin Media Library',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const LoginPage(),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (context) => const LoginPage());
          case '/media_libraries':
            final args = settings.arguments as Map<String, dynamic>?;
            if (args == null) {
              return MaterialPageRoute(
                builder: (context) => Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        const Text('缺少登录参数'),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => Navigator.pushReplacementNamed(context, '/'),
                          child: const Text('返回登录'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            return MaterialPageRoute(
              builder: (context) => MediaLibrariesPage(
                client: args['client'] as JellyfinClient,
                user: args['user'] as UserProfile,
              ),
            );
          case '/media_items':
            final args = settings.arguments as Map<String, dynamic>?;
            if (args == null) {
              return MaterialPageRoute(
                builder: (context) => Scaffold(
                  body: Center(
                    child: Text('缺少参数: ${settings.name}'),
                  ),
                ),
              );
            }
            return MaterialPageRoute(
              builder: (context) => MediaItemsPage(
                client: args['client'] as JellyfinClient,
                library: args['library'] as MediaLibrary,
              ),
            );
          default:
            return MaterialPageRoute(
              builder: (context) => Scaffold(
                body: Center(
                  child: Text('未找到路由: ${settings.name}'),
                ),
              ),
            );
        }
      },
    );
  }
}

// ==================== 登录页面 ====================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _serverController = TextEditingController(
    text: 'http://localhost:8096',
  );
  final _usernameController = TextEditingController(
    text: 'xue13',
  );
  final _passwordController = TextEditingController(
    text: '123456',
  );

  String _status = '请登录';
  bool _isLoading = false;

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_serverController.text.isEmpty) {
      setState(() => _status = '请输入服务器地址');
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
      print('🚀 开始登录流程...');
      print('   服务器: ${_serverController.text}');
      print('   用户名: ${_usernameController.text}');

      // 创建客户端
      final client = JellyfinClient(
        serverUrl: _serverController.text,
        enableLogging: true,
      );
      print('✅ 客户端创建成功');

      // 执行登录
      print('🔐 正在认证...');
      final result = await client.auth.authenticate(
        username: _usernameController.text,
        password: _passwordController.text,
      );

      print('✅ 认证成功!');
      print('   用户: ${result.user.name}');
      print('   用户ID: ${result.user.id}');
      print('   访问令牌: ${result.accessToken.substring(0, 10)}...');

      setState(() {
        _status = '✅ 登录成功! 正在跳转...';
        _isLoading = false;
      });

      // 登录成功，跳转到媒体库页面
      if (mounted) {
        print('🔄 开始页面跳转到 /media_libraries...');

        await Navigator.pushReplacementNamed(
          context,
          '/media_libraries',
          arguments: {
            'client': client,
            'user': result.user,
          },
        );

        print('✅ 页面跳转完成');
      } else {
        print('❌ Widget已销毁，无法跳转');
      }
    } catch (e, stackTrace) {
      print('❌ 登录失败: $e');
      print('   堆栈跟踪: $stackTrace');
      setState(() {
        _status = '❌ 登录失败: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _testConnection() async {
    if (_serverController.text.isEmpty) {
      setState(() => _status = '请输入服务器地址');
      return;
    }

    setState(() {
      _isLoading = true;
      _status = '正在测试连接...';
    });

    try {
      print('🔗 测试服务器连接...');
      print('   服务器: ${_serverController.text}');

      // 使用Dio直接测试连接
      final dio = Dio();
      final serverUrl = _serverController.text.trim();
      final testUrl = '$serverUrl/System/Info/Public';

      print('   测试URL: $testUrl');

      final response = await dio.get(
        testUrl,
        options: Options(
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      print('✅ 服务器连接成功!');
      print('   响应状态: ${response.statusCode}');

      if (response.statusCode == 200) {
        setState(() {
          _status = '✅ 服务器连接成功!';
          _isLoading = false;
        });

        // 3秒后清除成功消息
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() => _status = '准备登录');
          }
        });
      } else {
        throw Exception('服务器返回状态码: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('❌ 连接失败: $e');
      print('   堆栈跟踪: $stackTrace');
      setState(() {
        _status = '❌ 连接失败: ${e.toString()}';
        _isLoading = false;
      });
    }
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
                        // Logo和标题
                        Icon(
                          Icons.movie,
                          size: 64,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Jellyfin Media Library',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _status,
                          style: TextStyle(
                            color: _status.startsWith('❌')
                                ? Colors.red
                                : _status.startsWith('✅')
                                    ? Colors.green
                                    : Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),

                        // 服务器地址
                        TextField(
                          controller: _serverController,
                          decoration: const InputDecoration(
                            labelText: '服务器地址',
                            hintText: 'http://localhost:8096',
                            prefixIcon: Icon(Icons.dns),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 用户名
                        TextField(
                          controller: _usernameController,
                          decoration: const InputDecoration(
                            labelText: '用户名',
                            prefixIcon: Icon(Icons.person),
                            border: OutlineInputBorder(),
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),

                        // 密码
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: '密码',
                            prefixIcon: Icon(Icons.lock),
                            border: OutlineInputBorder(),
                          ),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _login(),
                        ),
                        const SizedBox(height: 16),

                        // 测试连接按钮
                        OutlinedButton.icon(
                          onPressed: _isLoading ? null : _testConnection,
                          icon: const Icon(Icons.wifi_find),
                          label: const Text('测试连接'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // 登录按钮
                        FilledButton(
                          onPressed: _isLoading ? null : _login,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('登录', style: TextStyle(fontSize: 16)),
                        ),

                        const SizedBox(height: 16),
                        const Text(
                          '登录成功后将跳转到媒体库页面',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
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

// ==================== 媒体库页面 ====================

class MediaLibrariesPage extends StatefulWidget {
  final JellyfinClient client;
  final UserProfile user;

  const MediaLibrariesPage({
    super.key,
    required this.client,
    required this.user,
  });

  @override
  State<MediaLibrariesPage> createState() => _MediaLibrariesPageState();
}

class _MediaLibrariesPageState extends State<MediaLibrariesPage> {
  List<MediaLibrary> _mediaLibraries = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    print('🔄 MediaLibrariesPage initState 调用');
    print('✅ 接收到参数:');
    print('   client: ${widget.client}');
    print('   user: ${widget.user.name}');

    // 加载媒体库
    print('📚 开始加载媒体库...');
    _loadMediaLibraries();
  }

  Future<void> _loadMediaLibraries() async {
    print('🔄 _loadMediaLibraries 开始执行');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('📡 调用 client.mediaLibrary.getMediaLibraries()...');
      final result = await widget.client.mediaLibrary.getMediaLibraries();

      print('✅ 媒体库获取成功!');
      print('   媒体库数量: ${result.libraries.length}');

      for (var i = 0; i < result.libraries.length; i++) {
        final lib = result.libraries[i];
        print('   [$i] ${lib.name} (${lib.type.displayName})');
      }

      setState(() {
        _mediaLibraries = result.libraries;
        _isLoading = false;
      });

      print('✅ UI状态更新完成');
    } catch (e, stackTrace) {
      print('❌ 获取媒体库失败: $e');
      print('   堆栈跟踪: $stackTrace');
      setState(() {
        _errorMessage = '获取媒体库失败: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    try {
      await widget.client.auth.logout();
    } catch (e) {
      print('登出失败: $e');
    }

    if (mounted) {
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('媒体库'),
        actions: [
          // 用户信息
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Text(
                widget.user.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          // 登出按钮
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: '登出',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadMediaLibraries,
        tooltip: '刷新',
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildBody() {
    print('🎨 _buildBody 被调用');
    print('   _isLoading: $_isLoading');
    print('   _errorMessage: $_errorMessage');
    print('   _mediaLibraries.length: ${_mediaLibraries.length}');

    if (_isLoading) {
      print('   显示加载指示器');
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在加载媒体库...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      print('   显示错误信息: $_errorMessage');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadMediaLibraries,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_mediaLibraries.isEmpty) {
      print('   显示空状态');
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '没有找到媒体库',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    print('   显示媒体库列表 (${_mediaLibraries.length} 个)');

    // 显示媒体库网格
    return RefreshIndicator(
      onRefresh: () async {
        print('🔄 刷新媒体库...');
        await _loadMediaLibraries();
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _mediaLibraries.length,
        itemBuilder: (context, index) {
          print('   构建卡片 [$index]: ${_mediaLibraries[index].name}');
          return MediaLibraryCard(
            client: widget.client,
            library: _mediaLibraries[index],
            onTap: () {
              print('🖱️ 点击了媒体库: ${_mediaLibraries[index].name}');
              Navigator.pushNamed(
                context,
                '/media_items',
                arguments: {
                  'client': widget.client,
                  'library': _mediaLibraries[index],
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ==================== 媒体库卡片 ====================

class MediaLibraryCard extends StatelessWidget {
  final JellyfinClient client;
  final MediaLibrary library;
  final VoidCallback onTap;

  const MediaLibraryCard({
    super.key,
    required this.client,
    required this.library,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    print('🎴 MediaLibraryCard.build: ${library.name}');
    print('   类型: ${library.type.displayName}');
    print('   有封面: ${library.hasCoverImage}');
    print('   ID: ${library.id}');
    print('   数量: ${library.itemCount}');

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 封面图片区域
            Expanded(
              flex: 3,
              child: _buildCoverImage(context),
            ),

            // 信息区域
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 媒体库名称
                    Text(
                      library.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 4),

                    // 类型和数量
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 类型行
                        Text(
                          '${library.type.icon} ${library.type.displayName}',
                          style: TextStyle(
                            color: _parseColor(library.type.color),
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        // 数量
                        if (library.itemCount != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Text(
                              '${library.itemCount} 项',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverImage(BuildContext context) {
    // 如果有封面，使用JellyfinImageWithClient加载认证图片
    if (library.hasCoverImage) {
      print('   使用JellyfinImage加载认证图片');

      return JellyfinImageWithClient(
        client: client,
        itemId: library.id,
        imageTag: library.primaryImageTag,
        fillWidth: 288,    // 使用你推荐的尺寸
        fillHeight: 428,
        fit: BoxFit.cover,
        placeholder: _buildPlaceholder(context),
        errorWidget: _buildPlaceholder(context),
      );
    }

    // 没有封面，显示占位图
    print('   使用占位图显示');
    return _buildPlaceholder(context);
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      color: _parseColor(library.type.color).withValues(alpha: 0.3),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              library.type.icon,
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 8),
            Text(
              library.type.displayName,
              style: TextStyle(
                color: _parseColor(library.type.color),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String hexColor) {
    try {
      final color = hexColor.replaceAll('#', '0xFF');
      return Color(int.parse(color));
    } catch (e) {
      return Colors.blue;
    }
  }
}

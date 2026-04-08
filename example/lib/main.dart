import 'package:flutter/material.dart';
import 'package:jellyfin_service/jellyfin_service.dart';

void main() {
  runApp(const JellyfinExampleApp());
}

class JellyfinExampleApp extends StatelessWidget {
  const JellyfinExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jellyfin Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}

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

    setState(() {
      _isLoading = true;
      _status = '正在登录...';
    });

    try {
      final client = JellyfinClient(
        serverUrl: _serverController.text,
        enableLogging: true,
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

/// 媒体库列表页面 - 从 main.dart 提取出来的业务页面
/// 登录后展示所有媒体库，点击进入对应类型的页面
class MediaLibrariesPage extends StatefulWidget {
  final JellyfinClient client;
  final UserProfile user;

  const MediaLibrariesPage({super.key, required this.client, required this.user});

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
    _loadMediaLibraries();
  }

  Future<void> _loadMediaLibraries() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final result = await widget.client.mediaLibrary.getMediaLibraries();
      setState(() { _mediaLibraries = result.libraries; _isLoading = false; });
    } catch (e) {
      setState(() { _errorMessage = '获取媒体库失败: $e'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('媒体库'),
        actions: [
          IconButton(icon: const Icon(Icons.person), onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => PersonalPage(client: widget.client)));
          }, tooltip: '个人中心'),
          IconButton(icon: const Icon(Icons.bug_report), onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => TestApiPage(client: widget.client)));
          }, tooltip: 'API测试'),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: Center(child: Text(widget.user.name, style: const TextStyle(fontWeight: FontWeight.bold)))),
          IconButton(icon: const Icon(Icons.logout), onPressed: () async {
            await widget.client.auth.logout();
            if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
          }, tooltip: '登出'),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody()),
          ListenableBuilder(
            listenable: AudioPlaybackManager.instance,
            builder: (context, _) {
              if (!AudioPlaybackManager.instance.hasPlaylist) return const SizedBox.shrink();
              return MiniPlayerCard(client: widget.client);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(onPressed: _loadMediaLibraries, tooltip: '刷新', child: const Icon(Icons.refresh)),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('正在加载媒体库...')]));
    if (_errorMessage != null) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.error_outline, size: 64, color: Colors.red), const SizedBox(height: 16), Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center), const SizedBox(height: 16), FilledButton(onPressed: _loadMediaLibraries, child: const Text('重试'))]));
    if (_mediaLibraries.isEmpty) return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.folder_open, size: 64, color: Colors.grey), SizedBox(height: 16), Text('没有找到媒体库', style: TextStyle(fontSize: 16, color: Colors.grey))]));

    return RefreshIndicator(
      onRefresh: _loadMediaLibraries,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.5, crossAxisSpacing: 12, mainAxisSpacing: 12),
        itemCount: _mediaLibraries.length,
        itemBuilder: (context, index) => _LibraryCard(
          client: widget.client,
          library: _mediaLibraries[index],
          onTap: () => _navigateToLibrary(_mediaLibraries[index]),
        ),
      ),
    );
  }

  void _navigateToLibrary(MediaLibrary library) {
    Widget page;
    if (library.type == MediaLibraryType.movies) {
      page = MovieFilterPage(client: widget.client, libraryId: library.id, libraryName: library.name);
    } else if (library.type == MediaLibraryType.music) {
      page = MusicLibraryPage(client: widget.client, libraryId: library.id, libraryName: library.name);
    } else {
      page = MediaItemsPage(client: widget.client, library: library);
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }
}

/// 媒体库卡片
class _LibraryCard extends StatelessWidget {
  final JellyfinClient client;
  final MediaLibrary library;
  final VoidCallback onTap;

  const _LibraryCard({required this.client, required this.library, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: library.hasCoverImage
                ? JellyfinImageWithClient(client: client, itemId: library.id, imageTag: library.primaryImageTag, fillWidth: 288, fillHeight: 428, fit: BoxFit.cover)
                : Container(color: Colors.blue.withValues(alpha: 0.3), child: Center(child: Text(library.type.icon, style: const TextStyle(fontSize: 48))))),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(library.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (library.itemCount != null)
                          Text('${library.itemCount} 项', style: TextStyle(color: Colors.grey[600], fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Text(library.type.icon, style: const TextStyle(fontSize: 20)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

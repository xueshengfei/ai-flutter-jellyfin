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
  List<MediaItem> _continueWatching = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final results = await Future.wait([
        widget.client.mediaLibrary.getMediaLibraries(),
        widget.client.user.getContinueWatching(limit: 10),
      ]);
      if (mounted) {
        setState(() {
          _mediaLibraries = (results[0] as MediaLibraryListResult).libraries;
          _continueWatching = (results[1] as MediaItemListResult).items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _errorMessage = '$e'; _isLoading = false; });
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
      floatingActionButton: FloatingActionButton(onPressed: _loadAll, tooltip: '刷新', child: const Icon(Icons.refresh)),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('正在加载...')]));
    if (_errorMessage != null) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.error_outline, size: 64, color: Colors.red), const SizedBox(height: 16), Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center), const SizedBox(height: 16), FilledButton(onPressed: _loadAll, child: const Text('重试'))]));

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 媒体库
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('媒体库', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _mediaLibraries.map((lib) => _LibraryCard(
              client: widget.client,
              library: lib,
              onTap: () => _navigateToLibrary(lib),
            )).toList(),
          ),
          // 继续观看
          if (_continueWatching.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('继续观看', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _continueWatching.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) =>
                    _ContinueWatchingCard(item: _continueWatching[index], client: widget.client),
              ),
            ),
          ],
        ],
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

/// 媒体库卡片（紧凑横条）
class _LibraryCard extends StatelessWidget {
  final JellyfinClient client;
  final MediaLibrary library;
  final VoidCallback onTap;

  const _LibraryCard({required this.client, required this.library, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: (MediaQuery.of(context).size.width - 42) / 2,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // 小图标/封面
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              clipBehavior: Clip.antiAlias,
              child: library.hasCoverImage
                  ? JellyfinImageWithClient(client: client, itemId: library.id, imageTag: library.primaryImageTag, fillWidth: 80, fillHeight: 80, fit: BoxFit.cover)
                  : Center(child: Text(library.type.icon, style: const TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(library.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (library.itemCount != null)
                    Text('${library.itemCount} 项', style: TextStyle(color: Colors.grey[600], fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 继续观看卡片
class _ContinueWatchingCard extends StatelessWidget {
  final MediaItem item;
  final JellyfinClient client;

  const _ContinueWatchingCard({required this.item, required this.client});

  @override
  Widget build(BuildContext context) {
    final progress = (item.playedPercentage ?? 0) / 100;
    final coverUrl = item.getCoverImageUrl();

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => VideoPlayerPage(client: client, item: item),
        ));
      },
      child: SizedBox(
        width: 130,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 封面 + 进度条
            Expanded(
              child: Stack(
                children: [
                  // 封面
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: coverUrl != null
                        ? Image.network(coverUrl, fit: BoxFit.cover, width: double.infinity, height: double.infinity,
                            errorBuilder: (_, __, ___) => _placeholder(context))
                        : _placeholder(context),
                  ),
                  // 底部蓝色进度条
                  if (progress > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 3,
                          backgroundColor: Colors.white.withValues(alpha: 0.3),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // 标题
            Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            // 副标题（类型 + 年份）
            Text(
              '${item.typeDisplayName}${item.productionYear != null ? ' · ${item.productionYear}' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) => Container(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Center(child: Icon(item.typeIcon != '' ? null : Icons.play_circle_outline,
        size: 32, color: Colors.white54)),
  );
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'network_simulator.dart';

/// Flutter 调试面板 — 悬浮按钮 + 可展开面板
///
/// 用法:
/// ```dart
/// void main() {
///   FlutterDebugPanel.init(enable: !kReleaseMode);
///   runApp(FlutterDebugPanel.wrap(MyApp()));
/// }
/// ```
class FlutterDebugPanel {
  FlutterDebugPanel._();

  static bool _enabled = false;

  /// 是否启用调试面板
  static bool get enabled => _enabled;

  /// 初始化调试面板
  static void init({bool enable = true}) {
    _enabled = enable && !kReleaseMode;
  }

  /// 包裹应用根组件，添加悬浮调试按钮
  static Widget wrap(Widget app) {
    if (!_enabled) return app;
    return _DebugPanelWrapper(child: app);
  }
}

// ==================== 内部实现 ====================

/// 根 Wrapper：Stack 中放置 app + 悬浮按钮 + 面板
///
/// 因为 FAB 是 MaterialApp 的兄弟节点，不能用 MediaQuery / Navigator / Overlay，
/// 所以用 View.of(context) 获取屏幕尺寸，面板直接用 Stack 的 child 管理。
class _DebugPanelWrapper extends StatefulWidget {
  const _DebugPanelWrapper({required this.child});

  final Widget child;

  @override
  State<_DebugPanelWrapper> createState() => _DebugPanelWrapperState();
}

class _DebugPanelWrapperState extends State<_DebugPanelWrapper> {
  bool _panelOpen = false;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            widget.child,
            _DraggableFab(
              panelOpen: _panelOpen,
              onToggle: () => setState(() => _panelOpen = !_panelOpen),
            ),
            if (_panelOpen)
              _DebugPanelOverlay(
                onClose: () => setState(() => _panelOpen = false),
              ),
          ],
        ),
      ),
    );
  }
}

/// 可拖拽悬浮按钮
///
/// 使用 onPanStart/Update/End 统一处理拖拽和点击：
/// - 拖拽距离 < 8px 视为点击（切换面板）
/// - 否则为拖拽（更新位置）
class _DraggableFab extends StatefulWidget {
  const _DraggableFab({
    required this.panelOpen,
    required this.onToggle,
  });

  final bool panelOpen;
  final VoidCallback onToggle;

  @override
  State<_DraggableFab> createState() => _DraggableFabState();
}

class _DraggableFabState extends State<_DraggableFab> {
  Offset _offset = const Offset(20, 100);
  Offset _dragStart = Offset.zero;
  Offset _fabStart = Offset.zero;
  bool _isDragging = false;

  /// 通过 View.of 获取逻辑屏幕尺寸（不依赖 MediaQuery）
  Size get _screenSize {
    final view = View.of(context);
    return Size(
      view.physicalSize.width / view.devicePixelRatio,
      view.physicalSize.height / view.devicePixelRatio,
    );
  }

  void _onPanStart(DragStartDetails details) {
    _dragStart = details.globalPosition;
    _fabStart = _offset;
    _isDragging = false;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final totalDelta = (details.globalPosition - _dragStart).distance;
    if (totalDelta > 8) _isDragging = true;

    if (_isDragging) {
      final screen = _screenSize;
      setState(() {
        _offset = Offset(
          (_fabStart.dx + details.globalPosition.dx - _dragStart.dx)
              .clamp(0.0, screen.width - 48),
          (_fabStart.dy + details.globalPosition.dy - _dragStart.dy)
              .clamp(0.0, screen.height - 48),
        );
      });
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isDragging) {
      widget.onToggle();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _offset.dx,
      top: _offset.dy,
      child: GestureDetector(
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: widget.panelOpen
                ? Colors.deepPurple
                : Colors.deepPurple.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            widget.panelOpen ? Icons.close : Icons.bug_report,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}

/// 调试面板（全屏半透明背景 + 居中面板）
class _DebugPanelOverlay extends StatefulWidget {
  const _DebugPanelOverlay({required this.onClose});

  final VoidCallback onClose;

  @override
  State<_DebugPanelOverlay> createState() => _DebugPanelOverlayState();
}

class _DebugPanelOverlayState extends State<_DebugPanelOverlay> {
  /// 选中的日志条目（null 表示列表视图，非 null 表示详情视图）
  RequestLogEntry? _selectedLog;

  @override
  void initState() {
    super.initState();
    SlowNetSimulator.instance.onLogUpdated = _onLogUpdated;
  }

  void _onLogUpdated() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    SlowNetSimulator.instance.onLogUpdated = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final simulator = SlowNetSimulator.instance;
    final currentSpeed = simulator.speed;
    final failurePct = (simulator.failureProbability * 100).round();

    // 通过 View.of 获取屏幕尺寸
    final view = View.of(context);
    final screenWidth = view.physicalSize.width / view.devicePixelRatio;
    final screenHeight = view.physicalSize.height / view.devicePixelRatio;

    // 顶部状态栏高度估算（SafeArea 替代）
    final paddingTop = view.padding.top / view.devicePixelRatio;

    return Positioned.fill(
      child: Material(
        color: Colors.black54,
        child: Padding(
          padding: EdgeInsets.only(top: paddingTop),
          child: Center(
            child: Container(
              width: screenWidth * 0.9,
              height: screenHeight * 0.75,
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  // 标题栏
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(
                      color: Colors.deepPurple,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.bug_report, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          '调试面板',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: IconButton(
                            onPressed: widget.onClose,
                            icon: const Icon(Icons.close, color: Colors.white),
                            iconSize: 20,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 网络速度选择
                  _buildSectionTitle('网络速度模拟'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildSpeedChip(null, '关闭', currentSpeed == null),
                        ...NetworkSpeed.values.map((s) => _buildSpeedChip(s, s.label, currentSpeed == s)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 失败率滑块
                  _buildSectionTitle('模拟失败率: $failurePct%'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Text('0%', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        Expanded(
                          child: Slider(
                            value: simulator.failureProbability,
                            min: 0.0,
                            max: 0.5,
                            divisions: 50,
                            activeColor: failurePct > 20 ? Colors.redAccent : Colors.deepPurple,
                            onChanged: (v) {
                              SlowNetSimulator.configure(
                                speed: currentSpeed,
                                failureProbability: v,
                              );
                              setState(() {});
                            },
                          ),
                        ),
                        const Text('50%', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // 请求日志 / 详情
                  if (_selectedLog != null)
                    Expanded(
                      child: _buildLogDetail(_selectedLog!),
                    )
                  else ...[
                    _buildSectionTitle('请求日志 (${simulator.logs.length})'),
                    Expanded(
                      child: _buildLogList(simulator),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildSpeedChip(NetworkSpeed? speed, String label, bool selected) {
    return GestureDetector(
      onTap: () {
        if (speed == null) {
          SlowNetSimulator.disable();
        } else {
          SlowNetSimulator.configure(
            speed: speed,
            failureProbability: SlowNetSimulator.instance.failureProbability,
          );
        }
        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.deepPurple : Colors.grey.shade800,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.deepPurple : Colors.grey.shade700,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildLogList(SlowNetSimulator simulator) {
    final logs = simulator.logs;
    if (logs.isEmpty) {
      return const Center(
        child: Text('暂无请求日志', style: TextStyle(color: Colors.grey, fontSize: 14)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        final isSuccess = log.statusCode != null && log.statusCode! >= 200 && log.statusCode! < 400;
        final isSimulatedFail = log.simulatedFailure;

        return GestureDetector(
          onTap: () => setState(() => _selectedLog = log),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSimulatedFail
                    ? Colors.red.withValues(alpha: 0.15)
                    : isSuccess
                        ? Colors.green.withValues(alpha: 0.08)
                        : Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSimulatedFail
                      ? Colors.red.withValues(alpha: 0.3)
                      : isSuccess
                          ? Colors.green.withValues(alpha: 0.2)
                          : Colors.orange.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          log.method,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (log.statusCode != null)
                        Text(
                          '${log.statusCode}',
                          style: TextStyle(
                            color: isSuccess ? Colors.greenAccent : Colors.orangeAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      const Spacer(),
                      if (log.simulatedDelay != null && log.simulatedDelay! > Duration.zero)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '+${log.simulatedDelay!.inMilliseconds}ms',
                            style: const TextStyle(color: Colors.amber, fontSize: 10),
                          ),
                        ),
                      if (isSimulatedFail)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '模拟失败',
                            style: TextStyle(color: Colors.redAccent, fontSize: 10),
                          ),
                        ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, color: Colors.grey.shade600, size: 16),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _truncateUrl(log.url),
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (log.errorMsg != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      log.errorMsg!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 请求详情视图
  Widget _buildLogDetail(RequestLogEntry log) {
    return Column(
      children: [
        // 返回按钮栏
        GestureDetector(
          onTap: () => setState(() => _selectedLog = null),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.grey.shade800,
            child: const Row(
              children: [
                Icon(Icons.arrow_back, color: Colors.white70, size: 18),
                SizedBox(width: 8),
                Text('返回日志列表', style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
        ),
        // 详情内容
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 概览
                _buildDetailRow('Method', log.method),
                _buildDetailRow('URL', log.url),
                _buildDetailRow('Status', log.statusCode != null ? '${log.statusCode}' : '-'),
                _buildDetailRow('Time', _formatTime(log.timestamp)),
                if (log.duration != null)
                  _buildDetailRow('Duration', '${log.duration!.inMilliseconds}ms'),
                if (log.simulatedDelay != null && log.simulatedDelay! > Duration.zero)
                  _buildDetailRow('Simulated Delay', '+${log.simulatedDelay!.inMilliseconds}ms'),
                if (log.errorMsg != null)
                  _buildDetailRow('Error', log.errorMsg!, valueColor: Colors.redAccent),

                const SizedBox(height: 12),

                // 请求头
                if (log.requestHeaders != null && log.requestHeaders!.isNotEmpty) ...[
                  _buildDetailSection('Request Headers', log.requestHeaders!),
                  const SizedBox(height: 12),
                ],

                // 请求体
                if (log.requestBody != null && log.requestBody!.isNotEmpty) ...[
                  _buildDetailSectionText('Request Body', log.requestBody!),
                  const SizedBox(height: 12),
                ],

                // 响应头
                if (log.responseHeaders != null && log.responseHeaders!.isNotEmpty) ...[
                  _buildDetailSection('Response Headers', log.responseHeaders!),
                  const SizedBox(height: 12),
                ],

                // 响应体
                if (log.responseBody != null && log.responseBody!.isNotEmpty) ...[
                  _buildDetailSectionText('Response Body', log.responseBody!),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(color: valueColor ?? Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, Map<String, dynamic> map) {
    final entries = map.entries.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.deepPurple.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: entries.map((e) {
              final val = e.value is List ? (e.value as List).join(', ') : '${e.value}';
              return Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: SelectableText(
                  '${e.key}: $val',
                  style: TextStyle(color: Colors.grey.shade300, fontSize: 11),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailSectionText(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.deepPurple.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 300),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(6),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              content,
              style: TextStyle(
                color: Colors.greenAccent.shade100,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}.'
        '${time.millisecond.toString().padLeft(3, '0')}';
  }

  String _truncateUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path;
      final query = uri.hasQuery ? '?${uri.query}' : '';
      return '$path$query';
    } catch (_) {
      return url.length > 80 ? '${url.substring(0, 77)}...' : url;
    }
  }
}

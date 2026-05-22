import 'package:flutter/material.dart';
import 'package:jellyfin_playback/src/models/watch_assist_models.dart';

class WatchAssistSheet extends StatefulWidget {
  final String itemId;
  final int initialPositionSeconds;
  final WatchAssistFetcher fetchWatchAssist;

  const WatchAssistSheet({
    super.key,
    required this.itemId,
    required this.initialPositionSeconds,
    required this.fetchWatchAssist,
  });

  @override
  State<WatchAssistSheet> createState() => _WatchAssistSheetState();
}

class _WatchAssistSheetState extends State<WatchAssistSheet> {
  WatchAssistSpoilerMode _mode = WatchAssistSpoilerMode.safe;
  WatchAssistType _assistType = WatchAssistType.currentStage;
  WatchAssistResponse? _response;
  Object? _error;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await widget.fetchWatchAssist(
        WatchAssistRequest(
          itemId: widget.itemId,
          positionSeconds: widget.initialPositionSeconds,
          spoilerMode: _mode,
          assistType: _assistType,
          subtitleWindow: null,
        ),
      );
      if (!mounted) return;
      setState(() {
        _response = response;
        _assistType = response.assistType;
        _mode = response.mode;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _isLoading = false;
      });
    }
  }

  void _selectMode(WatchAssistSpoilerMode mode) {
    if (mode == _mode) return;
    setState(() => _mode = mode);
    _load();
  }

  void _selectType(WatchAssistType type) {
    if (type == _assistType && !_isLoading) return;
    setState(() => _assistType = type);
    _load();
  }

  List<WatchAssistTypeOption> get _assistOptions {
    final options = _response?.availableAssistTypes;
    if (options != null && options.isNotEmpty) return options;
    return WatchAssistType.values
        .map(
          (type) => WatchAssistTypeOption(
            type: type,
            label: type.label,
            requiresSpoiler: type.requiresSpoiler,
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        constraints: const BoxConstraints(maxHeight: 560),
        decoration: const BoxDecoration(
          color: Color(0xFF171717),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'AI 解读',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if ((_response?.capabilityLabel ?? '').isNotEmpty)
                  _Badge(text: _response!.capabilityLabel),
              ],
            ),
            if ((_response?.progressStage ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _response!.progressStage,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
            if ((_response?.notice ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _response!.notice,
                style: const TextStyle(color: Colors.amberAccent, fontSize: 12),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: WatchAssistSpoilerMode.values
                  .map(
                    (mode) => ChoiceChip(
                      label: Text(mode.label),
                      selected: mode == _mode,
                      onSelected: (_) => _selectMode(mode),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _assistOptions
                  .map(
                    (option) => ChoiceChip(
                      label: Text(option.label),
                      selected: option.type == _assistType,
                      onSelected: (_) => _selectType(option.type),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        key: ValueKey('watch-assist-loading'),
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Center(
        key: const ValueKey('watch-assist-error'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '解读失败：$_error',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }

    final content = _response?.activeContent;
    if (content == null) {
      return const SizedBox.shrink(key: ValueKey('watch-assist-empty'));
    }

    return SingleChildScrollView(
      key: const ValueKey('watch-assist-content'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (content.title.isNotEmpty)
            Text(
              content.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (content.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              content.text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ],
          if (content.items.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...content.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 7),
                      child: Icon(Icons.circle, size: 5, color: Colors.white54),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;

  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:jellyfin_service/src/ui/models/view_mode_models.dart';
import 'package:jellyfin_service/src/ui/services/view_mode_manager.dart';

/// 视图模式选择器
///
/// 显示在AppBar中，允许用户切换视图模式
class ViewModeSelector extends StatefulWidget {
  final String? libraryId;
  final ValueChanged<ViewModeConfig>? onViewModeChanged;
  final bool showGridColumnSelector;

  const ViewModeSelector({
    super.key,
    this.libraryId,
    this.onViewModeChanged,
    this.showGridColumnSelector = true,
  });

  @override
  State<ViewModeSelector> createState() => _ViewModeSelectorState();
}

class _ViewModeSelectorState extends State<ViewModeSelector> {
  final ViewModeManager _viewModeManager = ViewModeManager();
  ViewModeConfig? _currentConfig;

  @override
  void initState() {
    super.initState();
    _loadViewMode();
  }

  Future<void> _loadViewMode() async {
    final config = await _viewModeManager.getViewModeConfig(widget.libraryId);
    if (mounted) {
      setState(() {
        _currentConfig = config;
      });
    }
  }

  Future<void> _setViewMode(ViewMode viewMode) async {
    await _viewModeManager.setViewMode(widget.libraryId, viewMode);
    await _loadViewMode();
    widget.onViewModeChanged?.call(_currentConfig!);
  }

  Future<void> _setGridColumn(GridColumn column) async {
    await _viewModeManager.setGridColumn(widget.libraryId, column);
    await _loadViewMode();
    widget.onViewModeChanged?.call(_currentConfig!);
  }

  void _showGridColumnMenu() {
    if (_currentConfig == null) return;

    // 只有海报和卡片视图才支持切换列数
    if (_currentConfig!.viewMode != ViewMode.poster &&
        _currentConfig!.viewMode != ViewMode.card) {
      return;
    }

    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect rect = RelativeRect.fromRect(
      button.localToGlobal(Offset.zero) & button.size,
      Offset.zero & overlay.size,
    );

    showMenu<int>(
      context: context,
      position: rect,
      items: GridColumn.values.map((column) {
        return PopupMenuItem<int>(
          value: column.index,
          child: Row(
            children: [
              Icon(
                _currentConfig!.gridColumn == column
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              const SizedBox(width: 8),
              Text(column.displayName),
            ],
          ),
          onTap: () => _setGridColumn(column),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentConfig == null) {
      return const SizedBox.shrink();
    }

    final canChangeColumns = _currentConfig!.viewMode == ViewMode.poster ||
        _currentConfig!.viewMode == ViewMode.card;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 视图模式切换按钮
        PopupMenuButton<ViewMode>(
          icon: Icon(_currentConfig!.viewMode.icon),
          tooltip: '切换视图模式',
          onSelected: _setViewMode,
          itemBuilder: (context) {
            return ViewMode.values.map((mode) {
              final isSelected = _currentConfig!.viewMode == mode;
              return PopupMenuItem<ViewMode>(
                value: mode,
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                    ),
                    const SizedBox(width: 8),
                    Text(mode.displayName),
                  ],
                ),
              );
            }).toList();
          },
        ),

        // 网格列数选择按钮（仅在海报和卡片视图时显示）
        if (widget.showGridColumnSelector && canChangeColumns)
          IconButton(
            icon: const Icon(Icons.grid_view),
            tooltip: '网格列数：${_currentConfig!.gridColumn.displayName}',
            onPressed: _showGridColumnMenu,
          ),
      ],
    );
  }
}

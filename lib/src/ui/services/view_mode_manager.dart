import 'package:shared_preferences/shared_preferences.dart';
import 'package:jellyfin_service/src/ui/models/view_mode_models.dart';

/// 视图模式管理服务
///
/// 负责管理视图模式的持久化存储和切换
class ViewModeManager {
  static const String _keyPrefix = 'view_mode_';
  static const String _gridColumnPrefix = 'grid_column_';

  /// 单例模式
  static final ViewModeManager _instance = ViewModeManager._internal();
  factory ViewModeManager() => _instance;

  ViewModeManager._internal();

  SharedPreferences? _prefs;

  /// 初始化
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// 确保 SharedPreferences 已初始化
  SharedPreferences get _preferences {
    if (_prefs == null) {
      throw Exception('ViewModeManager not initialized. Call init() first.');
    }
    return _prefs!;
  }

  /// 获取指定媒体库的视图模式配置
  ///
  /// [libraryId] 媒体库ID，如果为 null 则返回全局默认配置
  Future<ViewModeConfig> getViewModeConfig(String? libraryId) async {
    await init();

    final key = libraryId != null ? '${_keyPrefix}$libraryId' : '${_keyPrefix}default';
    final gridKey = libraryId != null ? '${_gridColumnPrefix}$libraryId' : '${_gridColumnPrefix}default';

    final viewModeIndex = _preferences.getInt(key) ?? ViewMode.poster.index;
    final gridColumnIndex = _preferences.getInt(gridKey) ?? GridColumn.three.index;

    return ViewModeConfig(
      viewMode: ViewMode.values[viewModeIndex],
      gridColumn: GridColumn.values[gridColumnIndex],
    );
  }

  /// 保存视图模式配置
  ///
  /// [libraryId] 媒体库ID，如果为 null 则保存为全局默认配置
  /// [config] 视图模式配置
  Future<void> saveViewModeConfig(String? libraryId, ViewModeConfig config) async {
    await init();

    final key = libraryId != null ? '${_keyPrefix}$libraryId' : '${_keyPrefix}default';
    final gridKey = libraryId != null ? '${_gridColumnPrefix}$libraryId' : '${_gridColumnPrefix}default';

    await _preferences.setInt(key, config.viewMode.index);
    await _preferences.setInt(gridKey, config.gridColumn.index);
  }

  /// 设置视图模式
  ///
  /// [libraryId] 媒体库ID
  /// [viewMode] 视图模式
  Future<void> setViewMode(String? libraryId, ViewMode viewMode) async {
    final config = await getViewModeConfig(libraryId);
    await saveViewModeConfig(libraryId, config.copyWith(viewMode: viewMode));
  }

  /// 设置网格列数
  ///
  /// [libraryId] 媒体库ID
  /// [gridColumn] 网格列数
  Future<void> setGridColumn(String? libraryId, GridColumn gridColumn) async {
    final config = await getViewModeConfig(libraryId);
    await saveViewModeConfig(libraryId, config.copyWith(gridColumn: gridColumn));
  }

  /// 重置为默认配置
  ///
  /// [libraryId] 媒体库ID，如果为 null 则重置全局默认配置
  Future<void> resetToDefault(String? libraryId) async {
    await init();

    final key = libraryId != null ? '${_keyPrefix}$libraryId' : '${_keyPrefix}default';
    final gridKey = libraryId != null ? '${_gridColumnPrefix}$libraryId' : '${_gridColumnPrefix}default';

    await _preferences.remove(key);
    await _preferences.remove(gridKey);
  }

  /// 清除所有视图模式配置
  Future<void> clearAll() async {
    await init();

    final keys = _preferences.getKeys();
    for (final key in keys) {
      if (key.startsWith(_keyPrefix) || key.startsWith(_gridColumnPrefix)) {
        await _preferences.remove(key);
      }
    }
  }
}

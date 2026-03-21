import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';

/// 视图模式枚举
enum ViewMode {
  /// 横幅视图 - 大横幅图片布局
  banner,

  /// 列表视图 - 垂直列表，左图右文
  list,

  /// 海报网格 - 竖版海报网格
  poster,

  /// 卡片网格 - 卡片式布局，包含更多信息
  card,
}

/// 网格列数枚举
enum GridColumn {
  two,
  three,
  four,
  five,
}

/// 视图模式配置
class ViewModeConfig extends Equatable {
  final ViewMode viewMode;
  final GridColumn gridColumn;

  const ViewModeConfig({
    this.viewMode = ViewMode.poster,
    this.gridColumn = GridColumn.three,
  });

  /// 获取网格列数
  int get crossAxisCount {
    switch (gridColumn) {
      case GridColumn.two:
        return 2;
      case GridColumn.three:
        return 3;
      case GridColumn.four:
        return 4;
      case GridColumn.five:
        return 5;
    }
  }

  /// 获取子项宽高比
  double get childAspectRatio {
    switch (viewMode) {
      case ViewMode.banner:
        return 2.5; // 横幅视图：宽一点
      case ViewMode.list:
        return 3.0; // 列表视图：列表项
      case ViewMode.poster:
        return 0.67; // 海报视图：竖版海报
      case ViewMode.card:
        return 0.7; // 卡片视图：略宽的海报
    }
  }

  /// 复制配置
  ViewModeConfig copyWith({
    ViewMode? viewMode,
    GridColumn? gridColumn,
  }) {
    return ViewModeConfig(
      viewMode: viewMode ?? this.viewMode,
      gridColumn: gridColumn ?? this.gridColumn,
    );
  }

  @override
  List<Object?> get props => [viewMode, gridColumn];
}

/// ViewMode 扩展方法
extension ViewModeExtension on ViewMode {
  /// 获取显示名称
  String get displayName {
    switch (this) {
      case ViewMode.banner:
        return '横幅';
      case ViewMode.list:
        return '列表';
      case ViewMode.poster:
        return '海报';
      case ViewMode.card:
        return '卡片';
    }
  }

  /// 获取图标
  IconData get icon {
    switch (this) {
      case ViewMode.banner:
        return Icons.view_stream;
      case ViewMode.list:
        return Icons.view_list;
      case ViewMode.poster:
        return Icons.view_module;
      case ViewMode.card:
        return Icons.dashboard;
    }
  }

  /// 获取工具提示
  String get tooltip {
    switch (this) {
      case ViewMode.banner:
        return '横幅视图';
      case ViewMode.list:
        return '列表视图';
      case ViewMode.poster:
        return '海报视图';
      case ViewMode.card:
        return '卡片视图';
    }
  }
}

/// GridColumn 扩展方法
extension GridColumnExtension on GridColumn {
  /// 获取显示名称
  String get displayName {
    switch (this) {
      case GridColumn.two:
        return '2列';
      case GridColumn.three:
        return '3列';
      case GridColumn.four:
        return '4列';
      case GridColumn.five:
        return '5列';
    }
  }

  /// 获取列数
  int get value {
    switch (this) {
      case GridColumn.two:
        return 2;
      case GridColumn.three:
        return 3;
      case GridColumn.four:
        return 4;
      case GridColumn.five:
        return 5;
    }
  }
}

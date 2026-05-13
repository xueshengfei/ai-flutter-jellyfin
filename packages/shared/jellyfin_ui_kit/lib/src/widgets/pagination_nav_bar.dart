import 'dart:math';

import 'package:flutter/material.dart';

/// 翻页导航条
///
/// 显示 "第 {from}-{to} / 共 {totalCount}" 格式，
/// 左右箭头按钮翻页，首页禁用 [◄]，末页禁用 [►]。
class PaginationNavBar extends StatelessWidget {
  /// 当前页起始偏移（0-based）
  final int startIndex;

  /// 每页条数
  final int pageSize;

  /// 数据总条数
  final int totalCount;

  /// 点击 [◄] 上一页
  final VoidCallback? onPrevious;

  /// 点击 [►] 下一页
  final VoidCallback? onNext;

  /// 是否正在加载
  final bool isLoading;

  const PaginationNavBar({
    super.key,
    required this.startIndex,
    required this.pageSize,
    required this.totalCount,
    this.onPrevious,
    this.onNext,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final from = totalCount == 0 ? 0 : startIndex + 1;
    final to = min(startIndex + pageSize, totalCount);
    final isFirstPage = startIndex == 0;
    final isLastPage = startIndex + pageSize >= totalCount;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // [◄] 上一页
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: isFirstPage || isLoading ? null : onPrevious,
            tooltip: '上一页',
          ),
          // 页码信息
          Expanded(
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      '第 $from-$to / 共 $totalCount',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
            ),
          ),
          // [►] 下一页
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: isLastPage || isLoading ? null : onNext,
            tooltip: '下一页',
          ),
        ],
      ),
    );
  }
}

import 'dart:math';

/// 分页数据结果
class PagedResult<T> {
  /// 当前页数据
  final List<T> items;

  /// 数据总条数
  final int totalCount;

  const PagedResult({
    required this.items,
    required this.totalCount,
  });

  /// 当前页起始编号（从 1 开始，用于显示）
  int displayFrom(int startIndex) => totalCount == 0 ? 0 : startIndex + 1;

  /// 当前页结束编号
  int displayTo(int startIndex, int pageSize) =>
      min(startIndex + pageSize, totalCount);
}

/// 分页数据获取回调
///
/// [startIndex] 起始偏移量（0-based）
/// [limit] 每页条数
typedef PagedFetcher<T> = Future<PagedResult<T>> Function({
  required int startIndex,
  required int limit,
});

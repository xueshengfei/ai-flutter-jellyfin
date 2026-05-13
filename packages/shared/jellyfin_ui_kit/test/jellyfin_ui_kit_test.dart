import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_ui_kit/jellyfin_ui_kit.dart';
import 'package:jellyfin_models/jellyfin_models.dart';

/// 测试用 Fake 图片提供者
class FakeImageProvider implements JellyfinImageProvider {
  final Uint8List? _imageData;
  final bool _shouldFail;
  int callCount = 0;
  String? lastItemId;

  FakeImageProvider({Uint8List? imageData, bool shouldFail = false})
      : _imageData = imageData,
        _shouldFail = shouldFail;

  @override
  String buildImageUrl({
    required String itemId,
    String? imageTag,
    int? fillWidth,
    int? fillHeight,
  }) {
    return 'http://test:8096/Items/$itemId/Images/Primary';
  }

  @override
  Map<String, String>? get authHeaders => null;

  @override
  Future<Uint8List> getPrimaryImage({
    required String itemId,
    String? tag,
    int? fillWidth,
    int? fillHeight,
    int? quality,
  }) async {
    callCount++;
    lastItemId = itemId;
    if (_shouldFail) throw Exception('加载失败');
    return _imageData ?? Uint8List.fromList([1, 2, 3, 4]);
  }
}

void main() {
  group('JellyfinImageProvider', () {
    test('FakeImageProvider 应正常返回数据', () async {
      final provider = FakeImageProvider();
      final data = await provider.getPrimaryImage(itemId: 'test-001');
      expect(data, isNotNull);
      expect(provider.callCount, 1);
      expect(provider.lastItemId, 'test-001');
    });

    test('FakeImageProvider 失败时应抛出异常', () async {
      final provider = FakeImageProvider(shouldFail: true);
      expect(
        () => provider.getPrimaryImage(itemId: 'fail-001'),
        throwsException,
      );
    });
  });

  group('ViewModeConfig', () {
    test('默认配置应为 poster + 三列', () {
      const config = ViewModeConfig();
      expect(config.viewMode, ViewMode.poster);
      expect(config.gridColumn, GridColumn.three);
      expect(config.crossAxisCount, 3);
    });

    test('crossAxisCount 应正确映射', () {
      expect(const ViewModeConfig(gridColumn: GridColumn.two).crossAxisCount, 2);
      expect(const ViewModeConfig(gridColumn: GridColumn.four).crossAxisCount, 4);
      expect(const ViewModeConfig(gridColumn: GridColumn.five).crossAxisCount, 5);
    });

    test('childAspectRatio 应按视图模式返回正确值', () {
      expect(const ViewModeConfig(viewMode: ViewMode.banner).childAspectRatio, 2.5);
      expect(const ViewModeConfig(viewMode: ViewMode.list).childAspectRatio, 3.0);
      expect(const ViewModeConfig(viewMode: ViewMode.poster).childAspectRatio, 0.67);
      expect(const ViewModeConfig(viewMode: ViewMode.card).childAspectRatio, 0.7);
    });

    test('copyWith 应正确复制', () {
      const config = ViewModeConfig();
      final copy = config.copyWith(viewMode: ViewMode.card, gridColumn: GridColumn.four);
      expect(copy.viewMode, ViewMode.card);
      expect(copy.gridColumn, GridColumn.four);
      // 原始不变
      expect(config.viewMode, ViewMode.poster);
    });

    test('Equatable 相等性', () {
      const a = ViewModeConfig(viewMode: ViewMode.list, gridColumn: GridColumn.two);
      const b = ViewModeConfig(viewMode: ViewMode.list, gridColumn: GridColumn.two);
      expect(a, equals(b));
    });
  });

  group('ViewMode 扩展', () {
    test('displayName 应返回中文名称', () {
      expect(ViewMode.banner.displayName, '横幅');
      expect(ViewMode.list.displayName, '列表');
      expect(ViewMode.poster.displayName, '海报');
      expect(ViewMode.card.displayName, '卡片');
    });

    test('tooltip 应返回中文提示', () {
      expect(ViewMode.banner.tooltip, '横幅视图');
      expect(ViewMode.list.tooltip, '列表视图');
    });
  });

  group('GridColumn 扩展', () {
    test('displayName 应返回列数名称', () {
      expect(GridColumn.two.displayName, '2列');
      expect(GridColumn.five.displayName, '5列');
    });

    test('value 应返回正确数值', () {
      expect(GridColumn.two.value, 2);
      expect(GridColumn.three.value, 3);
      expect(GridColumn.four.value, 4);
      expect(GridColumn.five.value, 5);
    });
  });

  group('JellyfinImage Widget', () {
    test('JellyfinImage 应创建成功', () {
      final provider = FakeImageProvider();
      final image = JellyfinImage(
        imageProvider: provider,
        itemId: 'test-001',
        imageTag: 'tag-001',
        fillWidth: 200,
        fillHeight: 300,
      );
      expect(image.itemId, 'test-001');
      expect(image.imageTag, 'tag-001');
      expect(image.fillWidth, 200);
      expect(image.fillHeight, 300);
      expect(image.fit, BoxFit.cover);
    });
  });

  group('LibraryCard Widget', () {
    test('LibraryCard 应接受 JellyfinImageProvider', () {
      final provider = FakeImageProvider();
      final card = LibraryCard(
        imageProvider: provider,
        library: const MediaLibrary(
          id: 'lib-001',
          name: '测试库',
          type: MediaLibraryType.movies,
          serverUrl: 'http://test:8096',
          itemCount: 50,
        ),
        onTap: () {},
      );
      expect(card.library.id, 'lib-001');
      expect(card.library.name, '测试库');
    });
  });

  group('MediaItemCard Widget', () {
    test('MediaItemCard 应接受 JellyfinImageProvider', () {
      final provider = FakeImageProvider();
      final card = MediaItemCard(
        imageProvider: provider,
        item: const MediaItem(
          id: 'item-001',
          name: '测试电影',
          type: 'Movie',
          serverUrl: 'http://test:8096',
          productionYear: 2024,
          communityRating: 8.5,
        ),
        onTap: () {},
      );
      expect(card.item.id, 'item-001');
      expect(card.item.name, '测试电影');
    });
  });
}

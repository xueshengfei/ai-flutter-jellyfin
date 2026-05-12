#!/usr/bin/env dart
/// 模块边界检查脚本
///
/// 检查 feature 包是否遵守模块边界规则：
/// 1. 不 import 根包 `jellyfin_service`
/// 2. 不 import 其他 feature 包的 `src/` 目录
/// 3. 外部不 import feature 包的 `src/` 目录
/// 4. hide 数量阈值检查（>20 时 fail）
/// 5. shared 包禁止 import feature 包
/// 6. foundation 包禁止 import feature 包
/// 7. 根 UI 页面 MaterialPageRoute 使用报告（信息性）
///
/// 用法：dart scripts/check_module_boundaries.dart

import 'dart:io';

const featuresDir = 'packages/features';
const sharedDir = 'packages/shared';
const foundationDir = 'packages/foundation';

/// hide 类型数量阈值（超过则 fail）
const hideThreshold = 20;

/// MaterialPageRoute 使用基线数量
/// 超过此基线时 fail，迁移完成后更新此值
const materialPageRouteBaseline = 41;

/// 需要检查跨模块 MaterialPageRoute 的根 UI 目录
const rootUiDir = 'lib/src/ui';

/// 检查根 UI 页面中是否有直接使用 MaterialPageRoute 的跨模块导航
///
/// 已迁移到 AppNavigator 的页面不报告。只报告仍使用旧
/// Navigator.push(MaterialPageRoute(...)) 的页面，作为迁移进度追踪。
List<String> _checkMaterialPageRoute(File file, String relativePath) {
  final violations = <String>[];
  final lines = file.readAsLinesSync();

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.contains('MaterialPageRoute') &&
        !line.startsWith('//') &&
        !line.startsWith('///')) {
      violations.add('  $relativePath L${i + 1}: $line');
    }
  }

  return violations;
}

/// 检查单个文件的 import 是否违规
List<String> _checkFile(File file, String packageName) {
  final violations = <String>[];
  final lines = file.readAsLinesSync();

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();

    // 匹配 import 语句
    final importMatch = RegExp(r'''import\s+['"]([^'"]+)['"]''').firstMatch(line);
    if (importMatch == null) continue;

    final importPath = importMatch.group(1)!;

    // 规则 1：禁止 import 根包 jellyfin_service
    if (importPath.contains('package:jellyfin_service/')) {
      violations.add('  L${i + 1}: import 根包 → $importPath');
    }

    // 规则 2：禁止 import 其他 feature 包的 src/
    final featureSrcMatch =
        RegExp(r'package:(jellyfin_\w+)/src/').firstMatch(importPath);
    if (featureSrcMatch != null) {
      final otherPackage = featureSrcMatch.group(1)!;
      if (otherPackage != packageName) {
        violations.add('  L${i + 1}: import 其他 feature 的 src/ → $importPath');
      }
    }
  }

  return violations;
}

/// 检查单个文件是否 import 了任何 feature 包
List<String> _checkFeatureImports(File file, String pkgLabel, Set<String> featureNames) {
  final violations = <String>[];
  final lines = file.readAsLinesSync();

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    final importMatch = RegExp(r'''import\s+['"]package:(jellyfin_\w+)/''').firstMatch(line);
    if (importMatch == null) continue;

    final pkgName = importMatch.group(1)!;
    if (featureNames.contains(pkgName)) {
      violations.add('  L${i + 1}: import feature 包 $pkgName → ${importMatch.group(0)}');
    }
  }

  return violations;
}

/// 递归获取目录下所有 .dart 文件
List<File> _listDartFiles(Directory dir) {
  final files = <File>[];
  if (!dir.existsSync()) return files;

  for (final entity in dir.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      files.add(entity);
    }
  }
  return files;
}

/// 统计 barrel 文件中的 hide 类型数量
int _countHideTypes(File barrelFile) {
  final content = barrelFile.readAsStringSync();
  final hideMatches = RegExp(r'\bhide\s+([^;]+);').allMatches(content);
  var count = 0;
  for (final match in hideMatches) {
    final hideList = match.group(1)!;
    count += hideList.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).length;
  }
  return count;
}

void main() {
  final features = Directory(featuresDir);
  if (!features.existsSync()) {
    stderr.writeln('错误: 找不到 $featuresDir 目录');
    exit(1);
  }

  print('=== 模块边界检查 ===\n');

  var totalViolations = 0;
  final packageDirs = features.listSync().whereType<Directory>();

  // 收集所有 feature 包名
  final featureNames = <String>{};
  for (final pkgDir in packageDirs) {
    featureNames.add(pkgDir.path.split(Platform.pathSeparator).last);
  }

  for (final pkgDir in packageDirs) {
    final packageName = pkgDir.path.split(Platform.pathSeparator).last;
    final srcDir = Directory('${pkgDir.path}/lib/src');

    if (!srcDir.existsSync()) continue;

    print('检查 $packageName ...');

    final dartFiles = _listDartFiles(srcDir);
    var pkgViolations = 0;

    for (final file in dartFiles) {
      final relativePath = file.path.replaceFirst(
        '${pkgDir.path}${Platform.pathSeparator}',
        '',
      );

      final violations = _checkFile(file, packageName);
      if (violations.isNotEmpty) {
        print('  $relativePath');
        for (final v in violations) {
          print(v);
        }
        pkgViolations += violations.length;
      }
    }

    if (pkgViolations == 0) {
      print('  ✓ 无违规');
    } else {
      print('  ✗ $pkgViolations 个违规');
    }
    print('');

    totalViolations += pkgViolations;
  }

  // 规则 3：检查根包是否 import 了 feature 包的 src/
  print('检查根包是否 import feature src/ ...');
  final rootLib = Directory('lib');
  var rootViolations = 0;

  if (rootLib.existsSync()) {
    for (final file in _listDartFiles(rootLib)) {
      final relativePath = file.path.replaceFirst('lib${Platform.pathSeparator}', '');
      final lines = file.readAsLinesSync();

      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        final match = RegExp(r'''import\s+['"]package:(jellyfin_\w+)/src/([^'"]+)['"]''')
            .firstMatch(line);
        if (match != null) {
          final pkgName = match.group(1)!;
          // 只检查 feature 包的 src/，不检查根包自身的 src/
          if (featureNames.contains(pkgName)) {
            print('  $relativePath L${i + 1}: import feature src/ → ${match.group(0)}');
            rootViolations++;
          }
        }
      }
    }
  }

  if (rootViolations == 0) {
    print('  ✓ 无违规');
  }
  print('');

  totalViolations += rootViolations;

  // 规则 4：hide 数量阈值检查
  print('检查根包 barrel hide 数量 ...');
  final barrelFile = File('lib/jellyfin_service.dart');
  if (barrelFile.existsSync()) {
    final hideCount = _countHideTypes(barrelFile);
    if (hideCount > hideThreshold) {
      print('  ✗ hide 类型数量 $hideCount > 阈值 $hideThreshold');
      totalViolations++;
    } else {
      print('  ✓ hide 类型数量 $hideCount（阈值 $hideThreshold）');
    }
  }
  print('');

  // 规则 5：shared 包禁止 import feature 包
  print('检查 shared 包是否 import feature 包 ...');
  final sharedLib = Directory('$sharedDir/lib');
  var sharedViolations = 0;
  if (sharedLib.existsSync()) {
    for (final file in _listDartFiles(sharedLib)) {
      final violations = _checkFeatureImports(file, 'shared', featureNames);
      if (violations.isNotEmpty) {
        final relativePath = file.path.replaceFirst('$sharedDir${Platform.pathSeparator}', '');
        print('  $relativePath');
        for (final v in violations) {
          print(v);
        }
        sharedViolations += violations.length;
      }
    }
  }
  if (sharedViolations == 0) {
    print('  ✓ 无违规');
  } else {
    print('  ✗ $sharedViolations 个违规');
  }
  print('');

  totalViolations += sharedViolations;

  // 规则 6：foundation 包禁止 import feature 包
  print('检查 foundation 包是否 import feature 包 ...');
  final foundationLib = Directory('$foundationDir/lib');
  var foundationViolations = 0;
  if (foundationLib.existsSync()) {
    for (final file in _listDartFiles(foundationLib)) {
      final violations = _checkFeatureImports(file, 'foundation', featureNames);
      if (violations.isNotEmpty) {
        final relativePath = file.path.replaceFirst('$foundationDir${Platform.pathSeparator}', '');
        print('  $relativePath');
        for (final v in violations) {
          print(v);
        }
        foundationViolations += violations.length;
      }
    }
  }
  if (foundationViolations == 0) {
    print('  ✓ 无违规');
  } else {
    print('  ✗ $foundationViolations 个违规');
  }
  print('');

  totalViolations += foundationViolations;

  // 规则 7：根 UI 页面使用直接 MaterialPageRoute 的基线守卫
  print('检查根 UI 页面是否使用直接 MaterialPageRoute（基线: $materialPageRouteBaseline）...');
  final rootUi = Directory(rootUiDir);
  final materialPageRouteUsages = <String>[];
  if (rootUi.existsSync()) {
    for (final file in _listDartFiles(rootUi)) {
      final relativePath = file.path.replaceFirst(
        'lib${Platform.pathSeparator}src${Platform.pathSeparator}ui${Platform.pathSeparator}',
        '',
      );
      materialPageRouteUsages.addAll(
        _checkMaterialPageRoute(file, relativePath),
      );
    }
  }
  if (materialPageRouteUsages.isEmpty) {
    print('  ✓ 无直接 MaterialPageRoute');
  } else if (materialPageRouteUsages.length <= materialPageRouteBaseline) {
    print('  ℹ ${materialPageRouteUsages.length}/$materialPageRouteBaseline 处仍使用 MaterialPageRoute（待迁移）');
    for (final usage in materialPageRouteUsages) {
      print(usage);
    }
  } else {
    print('  ✗ ${materialPageRouteUsages.length} 处 MaterialPageRoute 超过基线 $materialPageRouteBaseline（需迁移或更新基线）');
    for (final usage in materialPageRouteUsages) {
      print(usage);
    }
    totalViolations++;
  }
  print('');

  // 总结
  print('=== 结果 ===');
  if (totalViolations == 0) {
    print('✓ 所有模块边界检查通过');
    exit(0);
  } else {
    print('✗ 发现 $totalViolations 个边界违规');
    exit(1);
  }
}

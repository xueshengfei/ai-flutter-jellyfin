#!/usr/bin/env dart
/// 模块边界检查脚本
///
/// 检查 feature 包是否遵守模块边界规则：
/// 1. 不 import 根包 `jellyfin_service`
/// 2. 不 import 其他 feature 包的 `src/` 目录
/// 3. 外部不 import feature 包的 `src/` 目录
///
/// 用法：dart scripts/check_module_boundaries.dart

import 'dart:io';

const featuresDir = 'packages/features';

// 合法的对外 import 路径（barrel 文件），不视为违规
final _allowedPatterns = <RegExp>[];

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

void main() {
  final features = Directory(featuresDir);
  if (!features.existsSync()) {
    stderr.writeln('错误: 找不到 $featuresDir 目录');
    exit(1);
  }

  print('=== 模块边界检查 ===\n');

  var totalViolations = 0;
  final packageDirs = features.listSync().whereType<Directory>();

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

  // 收集所有 feature 包名
  final featureNames = <String>{};
  for (final pkgDir in packageDirs) {
    featureNames.add(pkgDir.path.split(Platform.pathSeparator).last);
  }

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

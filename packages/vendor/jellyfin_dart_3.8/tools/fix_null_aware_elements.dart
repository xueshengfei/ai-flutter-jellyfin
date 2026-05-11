/// Post-processing script to replace Dart 3.9+ null-aware element syntax
/// in generated .g.dart files with Dart 3.8-compatible if-element syntax.
library;

import 'dart:io';

void main() {
  final modelDir = Directory('lib/src/model');
  if (!modelDir.existsSync()) {
    stderr.writeln('Error: lib/src/model directory not found');
    exit(1);
  }

  int totalFiles = 0;
  int totalReplacements = 0;

  for (final file in modelDir.listSync().where((f) => f.path.endsWith('.g.dart'))) {
    final content = File(file.path).readAsStringSync();
    final result = StringBuffer();
    int i = 0;
    bool changed = false;

    while (i < content.length) {
      // Look for the pattern: 'Key': ? or just standalone ? at start of expression
      // Pattern 1: 'Key': ?expr  (key on same line as ?)
      final keyPattern = RegExp(r"'([^']+)': \?");
      final keyMatch = keyPattern.matchAsPrefix(content, i);

      if (keyMatch != null) {
        final key = keyMatch.group(1)!;
        final exprStart = keyMatch.end;
        // Find the end of the expression: , or } or ) at correct nesting level
        final exprEnd = _findExpressionEnd(content, exprStart);
        if (exprEnd > exprStart) {
          final expr = content.substring(exprStart, exprEnd).trimRight();
          final trailingComma = content.substring(exprEnd).startsWith(',') ? ',' : '';
          result.write("if ($expr != null) '$key': $expr$trailingComma");
          i = exprEnd + trailingComma.length;
          totalReplacements++;
          changed = true;
          continue;
        }
      }

      // Pattern 2: key on previous line, ?expr on next line (e.g. 'Key':\n    ?expr,)
      // This is already handled because the key is already written to result,
      // and we encounter just ?expr at the current position.
      // Check if we're at a standalone ? that starts an expression
      if (content[i] == '?' && i + 1 < content.length && !_isPartOfNullAwareAccess(content, i)) {
        // This is a null-aware element ? prefix, not a null-aware access ?.
        final exprStart = i + 1;
        final exprEnd = _findExpressionEnd(content, exprStart);
        if (exprEnd > exprStart) {
          final expr = content.substring(exprStart, exprEnd).trimRight();
          final trailingComma = content.substring(exprEnd).startsWith(',') ? ',' : '';
          // Need to find the key - it's in the result buffer, look backwards for 'Key':
          final resultStr = result.toString();
          final keyMatchInResult = RegExp(r"'([^']+)':\s*$").firstMatch(resultStr);
          if (keyMatchInResult != null) {
            final key = keyMatchInResult.group(1)!;
            // Remove the trailing 'Key': from result
            final cutPoint = resultStr.lastIndexOf("'${key}'");
            result.clear();
            result.write(resultStr.substring(0, cutPoint));
            result.write("if ($expr != null) '$key': $expr$trailingComma");
            i = exprEnd + trailingComma.length;
            totalReplacements++;
            changed = true;
            continue;
          }
        }
      }

      result.write(content[i]);
      i++;
    }

    if (changed) {
      File(file.path).writeAsStringSync(result.toString());
      totalFiles++;
    }
  }

  print('Fixed $totalReplacements null-aware elements in $totalFiles files.');
}

/// Check if ? at position i is part of a null-aware access (?.) rather than a null-aware element
bool _isPartOfNullAwareAccess(String content, int i) {
  if (i + 1 < content.length && content[i + 1] == '.') return true;
  if (i + 1 < content.length && content[i + 1] == '.') return true;
  // Check for ?..
  if (i + 2 < content.length && content[i + 1] == '.' && content[i + 2] == '.') return true;
  return false;
}

/// Find the end of an expression starting at position [start].
/// The expression ends at a comma or closing brace/paren that isn't inside
/// nested brackets/parens.
int _findExpressionEnd(String content, int start) {
  int depth = 0;
  int i = start;

  // Skip leading whitespace
  while (i < content.length && (content[i] == ' ' || content[i] == '\t')) {
    i++;
  }

  for (; i < content.length; i++) {
    final ch = content[i];

    if (ch == '(' || ch == '[' || ch == '{') {
      depth++;
    } else if (ch == ')' || ch == ']' || ch == '}') {
      if (depth == 0) {
        // This closing bracket belongs to the outer map
        return i;
      }
      depth--;
    } else if (ch == ',' && depth == 0) {
      return i;
    } else if (ch == ';' && depth == 0) {
      return i;
    }
  }

  return i;
}

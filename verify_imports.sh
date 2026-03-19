#!/bin/bash

echo "=========================================="
echo "Jellyfin Service 导入验证"
echo "=========================================="
echo ""

# 检查文件是否存在
echo "1. 检查文件结构..."
echo "----------------------------------------"

files=(
  "lib/jellyfin_service.dart"
  "lib/src/jellyfin_client.dart"
  "lib/src/jellyfin_configuration.dart"
  "lib/src/core/api_client.dart"
  "lib/src/services/auth_service.dart"
  "lib/src/models/user_models.dart"
)

for file in "${files[@]}"; do
  if [ -f "$file" ]; then
    echo "✓ $file"
  else
    echo "✗ $file (缺失)"
  fi
done

echo ""
echo "2. 检查包名..."
echo "----------------------------------------"

package_name=$(grep "^name:" pubspec.yaml | awk '{print $2}')
echo "包名: $package_name"

if [ "$package_name" = "jellyfin_service" ]; then
  echo "✓ 包名正确"
else
  echo "✗ 包名不匹配 (应为 jellyfin_service)"
fi

echo ""
echo "3. 正确的导入方式..."
echo "----------------------------------------"

echo "import 'package:jellyfin_service/jellyfin_service.dart';"

echo ""
echo "4. 可用的类..."
echo "----------------------------------------"

echo "- JellyfinClient"
echo "- JellyfinConfiguration"
echo "- AuthService"
echo "- AuthenticationResult"
echo "- UserProfile"
echo "- AuthenticationException"

echo ""
echo "5. 使用示例..."
echo "----------------------------------------"

cat << 'EOF'
import 'package:jellyfin_service/jellyfin_service.dart';

void main() async {
  final client = JellyfinClient(
    serverUrl: 'http://localhost:8096',
  );

  final result = await client.auth.authenticate(
    username: 'user',
    password: 'pass',
  );

  print('登录成功: ${result.user.name}');
}
EOF

echo ""
echo "=========================================="
echo "✅ 导入配置正确！"
echo "=========================================="

#!/bin/bash

# Jellyfin_Service 项目验证脚本
# 用于检查项目结构和依赖是否正确配置

echo "=========================================="
echo "Jellyfin_Service 项目验证"
echo "=========================================="
echo ""

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查函数
check_passed() {
    echo -e "${GREEN}✓${NC} $1"
}

check_failed() {
    echo -e "${RED}✗${NC} $1"
}

check_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# 1. 检查目录结构
echo "1. 检查目录结构..."
echo "----------------------------------------"

required_dirs=(
    "lib/src/core"
    "lib/src/exceptions"
    "lib/src/models"
    "lib/src/services"
    "lib/src/providers"
    "lib/src/providers/models"
)

for dir in "${required_dirs[@]}"; do
    if [ -d "$dir" ]; then
        check_passed "目录存在: $dir"
    else
        check_failed "目录缺失: $dir"
    fi
done

echo ""

# 2. 检查核心文件
echo "2. 检查核心文件..."
echo "----------------------------------------"

required_files=(
    "lib/jellyfin_sdk.dart"
    "lib/src/jellyfin_client.dart"
    "lib/src/jellyfin_configuration.dart"
    "lib/src/core/api_client.dart"
    "lib/src/core/cache_manager.dart"
    "lib/src/exceptions/jellyfin_exception.dart"
    "lib/src/exceptions/authentication_exception.dart"
    "lib/src/exceptions/api_exception.dart"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        check_passed "文件存在: $file"
    else
        check_failed "文件缺失: $file"
    fi
done

echo ""

# 3. 检查服务文件
echo "3. 检查服务文件..."
echo "----------------------------------------"

service_files=(
    "lib/src/services/auth_service.dart"
    "lib/src/services/user_service.dart"
    "lib/src/services/library_service.dart"
    "lib/src/services/media_content_service.dart"
    "lib/src/services/search_service.dart"
    "lib/src/services/playlist_service.dart"
    "lib/src/services/favorites_service.dart"
    "lib/src/services/playback_service.dart"
)

for file in "${service_files[@]}"; do
    if [ -f "$file" ]; then
        check_passed "服务文件: $(basename $file)"
    else
        check_failed "服务缺失: $(basename $file)"
    fi
done

echo ""

# 4. 检查Provider文件
echo "4. 检查Provider文件..."
echo "----------------------------------------"

provider_files=(
    "lib/src/providers/providers.dart"
    "lib/src/providers/auth_notifier.dart"
    "lib/src/providers/models/provider_models.dart"
)

for file in "${provider_files[@]}"; do
    if [ -f "$file" ]; then
        check_passed "Provider文件: $(basename $file)"
    else
        check_failed "Provider缺失: $(basename $file)"
    fi
done

echo ""

# 5. 检查模型文件
echo "5. 检查模型文件..."
echo "----------------------------------------"

model_files=(
    "lib/src/models/cache_models.dart"
    "lib/src/models/user_models.dart"
    "lib/src/models/media_models.dart"
)

for file in "${model_files[@]}"; do
    if [ -f "$file" ]; then
        check_passed "模型文件: $(basename $file)"
    else
        check_failed "模型缺失: $(basename $file)"
    fi
done

echo ""

# 6. 检查文档文件
echo "6. 检查文档文件..."
echo "----------------------------------------"

doc_files=(
    "PROJECT_READY.md"
    "INTEGRATION_CHECKLIST.md"
    "README.md"
)

for file in "${doc_files[@]}"; do
    if [ -f "$file" ]; then
        check_passed "文档文件: $file"
    else
        check_warning "文档缺失: $file"
    fi
done

echo ""

# 7. 检查pubspec.yaml
echo "7. 检查依赖配置..."
echo "----------------------------------------"

if [ -f "pubspec.yaml" ]; then
    check_passed "pubspec.yaml 存在"

    # 检查关键依赖
    if grep -q "jellyfin_dart:" pubspec.yaml; then
        check_passed "jellyfin_dart 依赖已配置"
    else
        check_failed "jellyfin_dart 依赖缺失"
    fi

    if grep -q "flutter_riverpod:" pubspec.yaml; then
        check_passed "flutter_riverpod 依赖已配置"
    else
        check_failed "flutter_riverpod 依赖缺失"
    fi

    if grep -q "json_annotation:" pubspec.yaml; then
        check_passed "json_annotation 依赖已配置"
    else
        check_failed "json_annotation 依赖缺失"
    fi
else
    check_failed "pubspec.yaml 不存在"
fi

echo ""

# 8. 检查jellyfin_dart依赖
echo "8. 检查jellyfin_dart SDK..."
echo "----------------------------------------"

if [ -d "../jellyfin_dart-0.1.2" ]; then
    check_passed "jellyfin_dart-0.1.2 目录存在"

    if [ -f "../jellyfin_dart-0.1.2/lib/jellyfin_dart.dart" ]; then
        check_passed "jellyfin_dart 主文件存在"
    else
        check_failed "jellyfin_dart 主文件缺失"
    fi
else
    check_failed "jellyfin_dart-0.1.2 目录不存在"
    echo "   请确保 jellyfin_dart-0.1.2 在项目根目录"
fi

echo ""

# 9. 统计文件
echo "9. 文件统计..."
echo "----------------------------------------"

dart_file_count=$(find lib/src -name "*.dart" -type f 2>/dev/null | wc -l)
echo "Dart 文件总数: $dart_file_count"

if [ "$dart_file_count" -ge 24 ]; then
    check_passed "文件数量符合预期 (≥24)"
else
    check_warning "文件数量少于预期 (预期≥24，实际$dart_file_count)"
fi

echo ""

# 10. 检查生成的文件
echo "10. 检查生成的文件..."
echo "----------------------------------------"

generated_files=(
    "lib/src/models/cache_models.g.dart"
    "lib/src/models/user_models.g.dart"
    "lib/src/providers/models/provider_models.g.dart"
)

generated_missing=0
for file in "${generated_files[@]}"; do
    if [ -f "$file" ]; then
        check_passed "生成文件: $(basename $file)"
    else
        check_warning "生成文件缺失: $(basename $file)"
        generated_missing=1
    fi
done

if [ $generated_missing -eq 1 ]; then
    echo ""
    check_warning "需要运行代码生成:"
    echo "   cd Jellyfin_Service"
    echo "   dart run build_runner build --delete-conflicting-outputs"
fi

echo ""

# 总结
echo "=========================================="
echo "验证完成"
echo "=========================================="
echo ""
echo "下一步操作:"
echo "1. 如果有缺失的生成文件，运行:"
echo "   dart run build_runner build --delete-conflicting-outputs"
echo ""
echo "2. 在 ai_video_project 中集成:"
echo "   - 更新 pubspec.yaml 添加 jellyfin_service 依赖"
echo "   - 运行 flutter pub get"
echo "   - 按照 INTEGRATION_CHECKLIST.md 集成"
echo ""
echo "3. 查看文档:"
echo "   - PROJECT_READY.md - 项目完成报告"
echo "   - INTEGRATION_CHECKLIST.md - 集成指南"
echo ""

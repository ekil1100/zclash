#!/usr/bin/env bash
set -euo pipefail

# zclash curl 一键安装脚本
# 用法: curl -fsSL https://raw.githubusercontent.com/ekil1100/zclash/main/scripts/install-curl.sh | bash

VERSION="${1:-latest}"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
REPO="ekil1100/zclash"

# 检测系统
detect_os() {
  case "$(uname -s)" in
    Linux*)     echo "linux";;
    Darwin*)    echo "macos";;
    *)          echo "unknown"; exit 1;;
  esac
}

detect_arch() {
  case "$(uname -m)" in
    x86_64|amd64) echo "amd64";;
    arm64|aarch64) echo "arm64";;
    *)            echo "unknown"; exit 1;;
  esac
}

OS=$(detect_os)
ARCH=$(detect_arch)

echo "=== zclash 一键安装 ==="
echo "版本: $VERSION"
echo "系统: $OS"
echo "架构: $ARCH"
echo "安装目录: $INSTALL_DIR"
echo ""

# 构建下载 URL
if [[ "$VERSION" == "latest" ]]; then
  URL="https://github.com/$REPO/releases/latest/download/zclash-${OS}-${ARCH}.tar.gz"
else
  URL="https://github.com/$REPO/releases/download/$VERSION/zclash-${VERSION}-${OS}-${ARCH}.tar.gz"
fi

echo "下载: $URL"

# 创建临时目录
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

# 下载
curl -fsSL "$URL" -o "$TMP_DIR/zclash.tar.gz" || {
  echo "❌ 下载失败"
  exit 1
}

# 解压
tar -xzf "$TMP_DIR/zclash.tar.gz" -C "$TMP_DIR" || {
  echo "❌ 解压失败"
  exit 1
}

# 查找可执行文件
BIN=$(find "$TMP_DIR" -name "zclash" -type f | head -1)
if [[ -z "$BIN" ]]; then
  echo "❌ 找不到可执行文件"
  exit 1
fi

# 安装
echo "安装到 $INSTALL_DIR..."
if [[ "$INSTALL_DIR" == "/usr/local/bin" ]]; then
  sudo mkdir -p "$INSTALL_DIR"
  sudo cp "$BIN" "$INSTALL_DIR/zclash"
  sudo chmod +x "$INSTALL_DIR/zclash"
else
  mkdir -p "$INSTALL_DIR"
  cp "$BIN" "$INSTALL_DIR/zclash"
  chmod +x "$INSTALL_DIR/zclash"
fi

# 验证
if command -v zclash >/dev/null 2>&1; then
  echo "✅ 安装成功"
  zclash --help | head -3
elif [[ -x "$INSTALL_DIR/zclash" ]]; then
  echo "✅ 安装成功"
  echo "请确保 $INSTALL_DIR 在 PATH 中，或直接运行: $INSTALL_DIR/zclash"
else
  echo "⚠️ 安装可能成功，但无法验证"
fi

echo ""
echo "下一步:"
echo "  1. 运行诊断: zclash doctor"
echo "  2. 查看帮助: zclash help"
echo "  3. 启动 TUI: zclash tui"

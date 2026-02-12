#!/usr/bin/env bash
set -euo pipefail

# Debian 包构建脚本
# 用法: bash scripts/build-deb.sh [version]

VERSION="${1:-v1.0.0}"
PKG_NAME="zclash"
PKG_VERSION="${VERSION#v}"
ARCH=$(dpkg --print-architecture 2>/dev/null || echo "amd64")
BUILD_DIR="$(pwd)/build-deb"

echo "=== Building .deb package ==="
echo "Version: $PKG_VERSION"
echo "Arch: $ARCH"

# 清理并创建目录
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/$PKG_NAME-$PKG_VERSION/DEBIAN"
mkdir -p "$BUILD_DIR/$PKG_NAME-$PKG_VERSION/usr/bin"
mkdir -p "$BUILD_DIR/$PKG_NAME-$PKG_VERSION/usr/lib/systemd/system"
mkdir -p "$BUILD_DIR/$PKG_NAME-$PKG_VERSION/etc/zclash"

# 构建
echo "Building zclash..."
zig build -Doptimize=ReleaseSafe

# 复制二进制文件
cp "zig-out/bin/zclash" "$BUILD_DIR/$PKG_NAME-$PKG_VERSION/usr/bin/"

# 创建 control 文件
cat > "$BUILD_DIR/$PKG_NAME-$PKG_VERSION/DEBIAN/control" <<EOF
Package: $PKG_NAME
Version: $PKG_VERSION
Section: net
Priority: optional
Architecture: $ARCH
Maintainer: Like <like@ekil.sh>
Description: High-performance proxy tool in Zig
 Compatible with Clash configuration format.
EOF

# 创建 systemd 服务文件
cat > "$BUILD_DIR/$PKG_NAME-$PKG_VERSION/usr/lib/systemd/system/zclash.service" <<EOF
[Unit]
Description=zclash proxy service
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/zclash start
ExecReload=/usr/bin/zclash restart
ExecStop=/usr/bin/zclash stop
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# 构建 deb 包
echo "Building .deb package..."
dpkg-deb --build "$BUILD_DIR/$PKG_NAME-$PKG_VERSION"

# 移动产物
mkdir -p "dist"
mv "$BUILD_DIR/$PKG_NAME-$PKG_VERSION.deb" "dist/${PKG_NAME}_${PKG_VERSION}_${ARCH}.deb"

echo "✅ Package built: dist/${PKG_NAME}_${PKG_VERSION}_${ARCH}.deb"

#!/usr/bin/env bash
set -euo pipefail

# zc 安装测试脚本
# 测试 Release 二进制安装、运行和清理

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="${SCRIPT_DIR}/.test-install-$$"
INSTALL_DIR="${TEST_DIR}/install"
VERSION="${1:-v1.0.0-rc1}"
REPO="ekil1100/zc"

cleanup() {
    echo "🧹 清理测试环境..."
    if [[ -d "${TEST_DIR}" ]]; then
        rm -rf "${TEST_DIR}"
        echo "✅ 已删除测试目录: ${TEST_DIR}"
    fi
}

trap cleanup EXIT

main() {
    echo "🚀 zc 安装测试 (${VERSION})"
    echo "================================"
    
    # 检测系统
    local os arch
    case "$(uname -s)" in
        Linux*)     os="linux";;
        Darwin*)    os="macos";;
        *)          echo "❌ 不支持的操作系统"; exit 1;;
    esac
    
    case "$(uname -m)" in
        x86_64|amd64) arch="amd64";;
        arm64|aarch64) arch="arm64";;
        *)          echo "❌ 不支持的架构"; exit 1;;
    esac
    
    echo "📦 系统: ${os} / ${arch}"
    
    # 创建测试目录
    mkdir -p "${INSTALL_DIR}"
    cd "${TEST_DIR}"
    
    # 下载 Release 二进制
    local pkg_name="zc-${VERSION}-${os}-${arch}"
    local tarball="${pkg_name}.tar.gz"
    local url="https://github.com/${REPO}/releases/download/${VERSION}/${tarball}"
    
    echo "⬇️  下载: ${url}"
    if ! curl -fsSL "${url}" -o "${tarball}"; then
        echo "❌ 下载失败"
        exit 1
    fi
    echo "✅ 下载成功"
    
    # 验证 checksum（忽略路径）
    local sha_url="${url}.sha256"
    echo "🔐 验证 checksum..."
    curl -fsSL "${sha_url}" -o "${tarball}.sha256.orig"
    # 提取 checksum 值，忽略文件名路径
    awk '{print $1}' "${tarball}.sha256.orig" > "${tarball}.sha256"
    echo "$(cat ${tarball}.sha256)  ${tarball}" > "${tarball}.sha256.check"
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 -c "${tarball}.sha256.check"
    else
        sha256sum -c "${tarball}.sha256.check"
    fi
    echo "✅ Checksum 验证通过"
    
    # 解压
    echo "📂 解压..."
    tar -xzf "${tarball}"
    echo "✅ 解压成功"
    
    # 安装到临时目录
    echo "📋 安装到: ${INSTALL_DIR}"
    cp "${pkg_name}/zc" "${INSTALL_DIR}/"
    cp "${pkg_name}/README.md" "${INSTALL_DIR}/" 2>/dev/null || true
    
    # 测试运行
    echo "🧪 测试运行..."
    "${INSTALL_DIR}/zc" --help > /dev/null 2>&1
    echo "✅ zc --help 执行成功"
    
    # 输出版本
    echo ""
    echo "📊 版本信息:"
    "${INSTALL_DIR}/zc" --help | head -5
    
    echo ""
    echo "🎉 安装测试完成!"
    echo "📍 安装路径: ${INSTALL_DIR}/zc"
    echo "🔍 文件大小: $(ls -lh "${INSTALL_DIR}/zc" | awk '{print $5}')"
    
    # 清理提示
    echo ""
    echo "⚠️  测试环境将在脚本退出时自动清理"
    echo "   如需保留，请在退出前手动复制: cp ${INSTALL_DIR}/zc /usr/local/bin/"
}

main "$@"

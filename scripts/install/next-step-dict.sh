#!/usr/bin/env bash
set -euo pipefail

install_next_step() {
  case "${1:-}" in
    arg_parse) echo "参数不完整：按帮助示例补全后重试" ;;
    permission) echo "权限不足：请改用可写目录（如 /tmp/zclash-bin）或提升权限后重试" ;;
    path) echo "路径不可用：请确认目标目录存在且可写" ;;
    conflict) echo "路径冲突：目标父路径是文件，换一个目录再试" ;;
    dependency_missing) echo "依赖缺失：请安装所需命令后重试" ;;
    not_installed) echo "尚未安装：先执行 install，再执行当前操作" ;;
    version_missing) echo "缺少版本信息：请提供 --version 或先恢复版本文件" ;;
    marker_missing) echo "安装标记缺失：先执行 install 再 verify" ;;
    binary_missing) echo "可执行文件缺失：重新执行 install 恢复 zclash shim" ;;
    remove_failed) echo "回滚删除失败：检查权限后重新执行 rollback" ;;
    evidence_missing) echo "证据归档缺失：先执行 run-beta-checklist.sh 再校验" ;;
    *) echo "请查看输出中的失败步骤并按提示重试" ;;
  esac
}

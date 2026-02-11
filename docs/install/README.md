# 一键安装最小方案契约（P6-2A）

## 1) 范围（install / verify / upgrade）

- `install`：安装可执行文件与基础目录结构
- `verify`：校验安装结果与运行前置条件
- `upgrade`：在保留回滚能力前提下升级到新版本

---

## 2) 最小接口契约

### 输入
- `action`：`install|verify|upgrade`
- `--target-dir`：安装目录（可选，默认 `/usr/local/bin`）
- `--version`：升级目标版本（upgrade 必填）

### 输出（机器可解析）
- `INSTALL_RESULT=PASS|FAIL`
- `INSTALL_ACTION=<install|verify|upgrade>`
- `INSTALL_REPORT=<path/to/report.json>`
- 失败时：`INSTALL_FAILED_STEP=<step>` + `INSTALL_NEXT_STEP=<hint>`

### 失败 next-step 约定
- 权限失败：提示切换有权限目录或调整权限后重试
- 路径失败：提示创建目录并校验 PATH
- 依赖失败：提示缺失依赖与最低版本
- 平台失败：提示正确平台包与替代动作

---

## 3) 最小脚本命名与目录约定

```text
scripts/install/
  common.sh          # 统一机器输出函数
  oc-install.sh      # install（脚手架）
  oc-verify.sh       # verify（脚手架）
  oc-upgrade.sh      # upgrade（脚手架）
  oc-run.sh          # 统一入口
```

说明：当前阶段先冻结命名与契约，脚手架允许空实现，但必须输出标准机器字段。

---

## 4) 3步安装试用（人话版，Beta）

1. **先安装**（把基础文件放到目标目录）
   ```bash
   bash scripts/install/oc-run.sh install --target-dir /tmp/zclash-bin
   ```
2. **再验证**（确认安装标记和版本信息可读）
   ```bash
   bash scripts/install/oc-run.sh verify --target-dir /tmp/zclash-bin
   ```
3. **最后升级**（模拟升级到新版本）
   ```bash
   bash scripts/install/oc-run.sh upgrade --target-dir /tmp/zclash-bin --version v0.1.0
   ```

如果失败，不要慌：看 `INSTALL_FAILED_STEP` 和 `INSTALL_NEXT_STEP`，按提示做下一步。

## 5) 验收命令（可执行）

```bash
# install/verify/upgrade 成功+失败样例回归
bash scripts/install/verify-install-flow.sh

# 跨环境最小套件（路径/权限/已有安装覆盖）
bash scripts/install/verify-install-env.sh
```

回归覆盖（最小集）：
- 成功：install -> verify -> upgrade
- 失败：verify before install / upgrade without version / upgrade before install
- 跨环境：普通用户路径 / 权限不足（模拟） / 已有安装覆盖

## 6) Beta 试用验收清单（人话版 + 证据路径）

### A. 安装通过
- 验收命令：
  - `bash scripts/install/oc-run.sh install --target-dir /tmp/zclash-beta`
- 通过条件：
  - 输出 `INSTALL_RESULT=PASS`
- 证据路径：
  - `/tmp/zclash-beta/.zclash_installed`
  - `/tmp/zclash-beta/.zclash_version`

### B. 验证通过
- 验收命令：
  - `bash scripts/install/oc-run.sh verify --target-dir /tmp/zclash-beta`
- 通过条件：
  - 输出 `INSTALL_RESULT=PASS`
  - 输出 `INSTALL_ACTION=verify`
- 证据路径：
  - `/tmp/zclash-beta/.zclash_installed`

### C. 升级通过
- 验收命令：
  - `bash scripts/install/oc-run.sh upgrade --target-dir /tmp/zclash-beta --version v0.2.0`
- 通过条件：
  - 输出 `INSTALL_RESULT=PASS`
  - `.zclash_version` 内容变更为目标版本
- 证据路径：
  - `/tmp/zclash-beta/.zclash_version`

### D. 失败与回滚可操作
- 验收命令：
  - `bash scripts/install/verify-install-flow.sh`
  - `bash scripts/install/verify-install-env.sh`
- 通过条件：
  - 失败场景输出 `INSTALL_FAILED_STEP` + `INSTALL_NEXT_STEP`
  - 回归脚本输出整体 PASS/FAIL 汇总
- 证据路径：
  - `/tmp/zclash-install-regression/*`
  - `/tmp/zclash-install-env/install-env-summary.json`

---

## 7) Beta 试用注意事项（常见失败 + next-step）

- `INSTALL_FAILED_STEP=arg-parse`
  - 场景：命令参数不完整或 action 错误
  - next-step：按提示使用 `bash scripts/install/oc-run.sh <install|verify|upgrade> ...`

- `INSTALL_FAILED_STEP=marker-missing`
  - 场景：未先执行 install 就 verify
  - next-step：先执行 install，再 verify

- `INSTALL_FAILED_STEP=version-missing`
  - 场景：升级缺少 `--version` 或版本文件缺失
  - next-step：补 `--version`，或先 install/verify 恢复版本文件

- `INSTALL_FAILED_STEP=not-installed`
  - 场景：未安装直接 upgrade
  - next-step：先 install，再 upgrade

以上失败场景与 `scripts/install/verify-install-flow.sh` 回归脚本保持一致。

标准输出字段（机器可解析）：
- `INSTALL_RESULT=PASS|FAIL`
- `INSTALL_ACTION=<install|verify|upgrade>`
- `INSTALL_REPORT=<path>`
- `INSTALL_FAILED_STEP=<step>`
- `INSTALL_NEXT_STEP=<hint>`
- `INSTALL_SUMMARY=<human-readable summary>`

# 一键安装最小方案契约（P6-2A）

## 1) 范围（install / verify / upgrade）

- `install`：安装可执行文件与基础目录结构
- `verify`：校验安装结果与运行前置条件
- `upgrade`：在保留回滚能力前提下升级到新版本

---

## 2) 最小接口契约

### 输入
- `action`：`install|verify|upgrade|rollback`
- `--target-dir`：安装目录（可选，默认 `/usr/local/bin`）
- `--version`：升级目标版本（upgrade 必填）

### 输出（机器可解析）
- `INSTALL_RESULT=PASS|FAIL`
- `INSTALL_ACTION=<install|verify|upgrade|rollback>`
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

（可选）**回滚清理**（删除安装标记/版本/shim）
```bash
bash scripts/install/oc-run.sh rollback --target-dir /tmp/zclash-bin
```

如果失败，不要慌：看 `INSTALL_FAILED_STEP` 和 `INSTALL_NEXT_STEP`，按提示做下一步。

## 5) 验收命令（可执行）

```bash
# install/verify/upgrade 成功+失败样例回归
bash scripts/install/verify-install-flow.sh

# 跨环境最小套件（路径/权限/已有安装覆盖/路径冲突）
bash scripts/install/verify-install-env.sh

# Beta 验收清单执行脚本（checklist runner）
bash scripts/install/run-beta-checklist.sh

# P6-7A 非模拟权限验证（真实受限路径，预期 FAIL 且含 next-step）
bash scripts/install/oc-run.sh install --target-dir /var/root/zclash-install-test

# P6-7B 多平台路径矩阵（3类路径组合）
bash scripts/install/verify-install-path-matrix.sh
```

回归覆盖（最小集）：
- 成功：install -> verify -> upgrade
- 失败：verify before install / upgrade without version / upgrade before install
- 跨环境：普通用户路径 / 权限不足（真实受限路径） / 权限不足（模拟） / 已有安装覆盖 / 目标路径冲突

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
- `INSTALL_ACTION=<install|verify|upgrade|rollback>`
- `INSTALL_REPORT=<path>`
- `INSTALL_FAILED_STEP=<step>`
- `INSTALL_NEXT_STEP=<hint>`
- `INSTALL_SUMMARY=<human-readable summary>`

Beta checklist runner 输出（机器+人类摘要）：
- `BETA_CHECKLIST_RESULT=PASS|FAIL`
- `BETA_CHECKLIST_PASS_RATE=<0-100>`
- `BETA_CHECKLIST_FAILED_ITEMS=<comma-separated ids>`
- `BETA_CHECKLIST_REPORT=<summary.json path>`
- `BETA_CHECKLIST_EVIDENCE=<comma-separated evidence roots>`
- `BETA_CHECKLIST_ARCHIVE_DIR=<archive dir>`
- `BETA_CHECKLIST_SUMMARY=<human-readable summary>`

## 8) Beta 证据归档规范

归档根目录：`docs/install/evidence/`
- `history/<run_id>/`：每次 checklist 运行的归档
- `latest`：指向最近一次运行的软链接

命名规范：
- `run_id = beta-checklist-YYYYMMDD-HHMMSS`

每次归档最小文件集：
- `summary.json`（汇总结果）
- `A.install.out`
- `B.verify.out`
- `C.upgrade.out`
- `D.flow.out`
- `D.env.out`

`summary.json` 字段规范（最小）：
- `run_id`
- `result` (`PASS|FAIL`)
- `pass_count`
- `total_count`
- `pass_rate`
- `failed_items` (array)
- `items` (array, each includes `id/result/evidence/note`)

路径矩阵回归输出（与 runner 字段口径对齐）：
- `INSTALL_RESULT=PASS|FAIL`
- `INSTALL_ACTION=path-matrix`
- `INSTALL_REPORT=<summary.json path>`
- `INSTALL_FAILED_STEP=<failed case ids>`
- `INSTALL_NEXT_STEP=<hint>`
- `INSTALL_MATRIX_FAILED_SAMPLES=<comma-separated ids>`
- `INSTALL_SUMMARY=<human-readable summary>`

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

## 4) 验收命令（可执行）

```bash
# 1) install
bash scripts/install/oc-run.sh install --target-dir /tmp/zclash-bin

# 2) verify
bash scripts/install/oc-run.sh verify --target-dir /tmp/zclash-bin

# 3) upgrade
bash scripts/install/oc-run.sh upgrade --target-dir /tmp/zclash-bin --version v0.1.0
```

标准输出字段（机器可解析）：
- `INSTALL_RESULT=PASS|FAIL`
- `INSTALL_ACTION=<install|verify|upgrade>`
- `INSTALL_REPORT=<path>`
- `INSTALL_FAILED_STEP=<step>`
- `INSTALL_NEXT_STEP=<hint>`

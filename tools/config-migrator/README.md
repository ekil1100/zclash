# config-migrator（P5-1B 最小执行框架）

## 1) 输入/输出契约

### 输入
- `input_path`：待检查配置文件路径（YAML）
- `mode`：`lint` | `autofix`
- `output_path`（可选）：autofix 输出路径（默认覆盖前先生成 `.bak`）

### 输出（统一 JSON）
```json
{
  "ok": true,
  "mode": "lint",
  "issues": [
    {"rule": "RULE_ID", "level": "error|warn", "path": "key.path", "message": "...", "fixable": true}
  ],
  "fixed": 0,
  "hint": "..."
}
```

- `ok=false` 表示存在 error 或执行失败
- `fixed` 表示 autofix 实际修复条数

---

## 2) 最小可验证规则（示例）

### 规则1：`PORT_TYPE_INT`
- 说明：`port/socks-port/mixed-port` 必须是整数
- 触发：字段为字符串或非法值
- autofix：可将纯数字字符串转为整数

### 规则2：`LOG_LEVEL_ENUM`
- 说明：`log-level` 仅允许 `debug|info|warning|error|silent`
- 触发：值不在枚举范围
- autofix：不可自动修复，给出建议值 `info`

---

## 3) 最小执行入口（占位）

建议入口：
- `bash tools/config-migrator/run.sh lint <input_path>`
- `bash tools/config-migrator/run.sh autofix <input_path> [output_path]`

当前阶段先固定契约与规则，下一步再实现真实解析与修复逻辑。

---

## 4) 样例迁移验证（P5-1C 最小3例）

样例输入：
- `tools/config-migrator/examples/sample-1.yaml`
- `tools/config-migrator/examples/sample-2.yaml`
- `tools/config-migrator/examples/sample-3.yaml`

复现命令：
```bash
bash tools/config-migrator/verify-samples.sh
```

输出：
- 总结果：`MIGRATOR_SAMPLES_RESULT=PASS|FAIL`
- 报告路径：`tools/config-migrator/reports/samples-report.json`
- 每个样例均含 `status`（PASS/FAIL）与 `reason`

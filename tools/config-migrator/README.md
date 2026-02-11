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

---

## 5) 迁移验证结果归档统一格式（P5-1D）

统一字段（单样例）：
- `sample_id`：样例标识（如 `sample-1`）
- `input`：输入文件路径
- `result`：`PASS|FAIL`
- `diff`：迁移差异摘要（可为空字符串）
- `hint`：修复或下一步建议

推荐归档结构：
```json
{
  "run_id": "migrator-samples-<ts>",
  "status": "PASS|FAIL",
  "results": [
    {
      "sample_id": "sample-1",
      "input": "tools/config-migrator/examples/sample-1.yaml",
      "result": "PASS",
      "diff": "mixed-port: \"7890\" -> 7890",
      "hint": "autofix applied for numeric port"
    }
  ]
}
```

与现有输出兼容映射：
- `sample` -> `sample_id`
- `status` -> `result`
- `reason` -> `hint`
- `autofix_output`/`*.fixed.yaml` 可用于生成 `diff`

---

## 6) 自动汇总脚本（P5-1E）

离线复现命令：
```bash
bash tools/config-migrator/summarize-results.sh
```

输出：
- `MIGRATOR_SUMMARY_RESULT=PASS|FAIL`
- `MIGRATOR_SUMMARY_REPORT=tools/config-migrator/reports/samples-summary.json`

汇总字段：
- `pass_count` / `fail_count`
- `failed_items[]`
- `results[]`（使用统一字段：`sample_id/input/result/diff/hint`）

---

## 7) 首批规则回归统一入口（P5-2D）

离线复现命令：
```bash
bash tools/config-migrator/run-regression.sh
```

覆盖范围：
- R1 `PORT_TYPE_INT`（verify-r1）
- R2 `LOG_LEVEL_ENUM`（lint + suggested=info）

输出：
- `MIGRATOR_REGRESSION_RESULT=PASS|FAIL`
- `MIGRATOR_REGRESSION_FAILED_RULES=<rule list>`
- `MIGRATOR_REGRESSION_REPORT=tools/config-migrator/reports/samples-summary.json`

归档兼容：
- 回归入口直接写 `samples-summary.json`，字段兼容统一格式：
  `sample_id/input/result/diff/hint`

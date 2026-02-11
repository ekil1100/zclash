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

## 2) 规则说明（R1 / R2）

### R1：`PORT_TYPE_INT`
- 输入条件：`port/socks-port/mixed-port` 为数字字符串（如 `"7890"`）
- 修复策略：autofix 将纯数字字符串转为整数（如 `7890`）
- 限制：仅处理纯数字字符串；非数字字符串不会强制转换

### R2：`LOG_LEVEL_ENUM`
- 输入条件：`log-level` 不在 `debug|info|warning|error|silent`
- 修复策略：不自动修复（`fixable=false`），输出建议值 `suggested=info`
- 限制：仅做枚举校验，不改写源配置

---

## 3) 最小命令示例（lint / autofix / regression）

```bash
# lint
bash tools/config-migrator/run.sh lint tools/config-migrator/examples/r1-port-string.yaml

# autofix
bash tools/config-migrator/run.sh autofix tools/config-migrator/examples/r1-port-string.yaml tools/config-migrator/reports/r1-port-string.fixed.yaml

# regression (R1+R2)
bash tools/config-migrator/run-regression.sh
```

输出行为对齐当前脚本：
- `run.sh lint`：返回 `issues[]`，R2 命中时含 `suggested=info`
- `run.sh autofix`：仅修复 R1（数字字符串端口）
- `run-regression.sh`：输出 `MIGRATOR_REGRESSION_RESULT` 与失败规则清单

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
- `MIGRATOR_REGRESSION_FAILED_SAMPLES=<sample id list>`
- `MIGRATOR_REGRESSION_REPORT=tools/config-migrator/reports/samples-summary.json`
- `MIGRATOR_REGRESSION_SUMMARY=...`（人类友好摘要：总数/失败规则/失败样例）

归档兼容：
- 回归入口直接写 `samples-summary.json`，字段兼容统一格式：
  `sample_id/input/result/diff/hint`

---

## 8) 摘要输出 i18n/本地化占位（P6-1B）

目标：
- 在不改变机器字段的前提下，扩展人类可读摘要的多语言文案。

兼容策略（关键）：
- 机器字段保持不变：
  - `MIGRATOR_REGRESSION_RESULT`
  - `MIGRATOR_REGRESSION_FAILED_RULES`
  - `MIGRATOR_REGRESSION_FAILED_SAMPLES`
  - `MIGRATOR_REGRESSION_REPORT`
- 人类可读字段可演进：
  - `MIGRATOR_REGRESSION_SUMMARY`（当前）
  - 后续可按 `lang` 选择文案模板，不影响机器解析。

占位示例：
- 文件：`tools/config-migrator/i18n.example.json`
- 文案键：
  - `regression.summary.pass`
  - `regression.summary.fail`
- 提供最小 `en` + `zh` 模板。

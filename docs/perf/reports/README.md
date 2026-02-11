# Profiling & Regression Baseline Scaffold（P4-1.A）

## 1) 目标

建立 zclash 性能回归最小脚手架，保证后续优化有统一口径：
- 可重复采样
- 可对比历史结果
- 可设置门禁阈值

---

## 2) 采样口径

### 2.1 执行原则
- 每轮至少执行 3 次采样，取中位数（median）作为本轮结果
- 采样环境尽量固定（机器/网络/配置）
- 指标统一记录到结构化文件（建议 JSON）

### 2.2 统计字段建议
- `run_id`
- `timestamp`
- `scenario`
- `samples[]`
- `median`
- `threshold`
- `pass`

---

## 3) 目录约定

```text
docs/perf/reports/
  README.md                  # 本文件：口径与规范
  baseline-template.json     # 基线结果模板（后续生成）
  latest.json                # 最新一次采样（后续生成）
  history/
    YYYY-MM-DD-<run_id>.json # 历史归档（后续生成）
```

---

## 4) 核心指标（含阈值占位）

> 当前阈值为占位值，后续按实测逐步收敛。

1. `rule_eval_p95_ms`
- 含义：规则匹配 p95 延迟
- 阈值占位：`<= 1.0 ms`

2. `dns_resolve_p95_ms`
- 含义：DNS 解析 p95 延迟
- 阈值占位：`<= 80 ms`

3. `throughput_rps`
- 含义：端到端吞吐（每秒请求数）
- 阈值占位：`>= 800 rps`

4. `reload_cost_ms`（可选扩展）
- 含义：配置重载耗时
- 阈值占位：`<= 500 ms`

---

## 5) 脚本接入指导（下一步）

后续脚本（建议：`scripts/perf/run-baseline.sh`）需至少完成：
1) 执行固定场景采样
2) 产出 `latest.json`
3) 对比阈值并输出 `pass/fail`
4) 将结果归档到 `history/`

输出示例（概念）：
```json
{
  "run_id": "p4a-001",
  "timestamp": "2026-02-11T09:40:00+08:00",
  "metrics": {
    "rule_eval_p95_ms": { "value": 0.82, "threshold": 1.0, "pass": true },
    "dns_resolve_p95_ms": { "value": 73.0, "threshold": 80.0, "pass": true },
    "throughput_rps": { "value": 910, "threshold": 800, "pass": true }
  }
}
```

---

## 6) 验收对齐（P4-1.A）

- [x] 定义 profiling 目标、采样口径、目录约定
- [x] 至少 3 个核心指标 + 阈值占位
- [x] 文档可直接指导脚本接入

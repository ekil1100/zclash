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
- 默认阈值占位：`<= 1.0 ms`
- 调整说明：
  - 若连续 3 轮稳定低于 0.7ms，可收紧到 `<= 0.8 ms`
  - 若新场景引入复杂规则，临时放宽不得超过 `<= 1.2 ms`

2. `dns_resolve_p95_ms`
- 含义：DNS 解析 p95 延迟
- 默认阈值占位：`<= 80 ms`
- 调整说明：
  - 若网络环境稳定且命中率提升，可收紧到 `<= 70 ms`
  - 若测试环境链路波动明显，临时放宽不得超过 `<= 100 ms`

3. `throughput_rps`
- 含义：端到端吞吐（每秒请求数）
- 默认阈值占位：`>= 800 rps`
- 调整说明：
  - 若 CPU/内存优化后稳定提升，可上调到 `>= 900 rps`
  - 若场景并发显著增大，临时下调不得低于 `>= 700 rps`

4. `reload_cost_ms`（可选扩展）
- 含义：配置重载耗时
- 阈值占位：`<= 500 ms`

---

## 5) 回归执行入口（本地 / CI 一致）

### 5.1 本地入口
- 命令：`bash scripts/perf/run-baseline.sh`
- 约定：
  - 读取本文件定义的指标阈值
  - 输出 `docs/perf/reports/latest.json`
  - 同步归档到 `docs/perf/reports/history/`

### 5.2 CI 入口
- 命令：`bash scripts/perf/run-baseline.sh`
- 约定：
  - 与本地完全同命令、同参数口径
  - CI 仅负责执行与门禁，不维护另一套脚本逻辑

### 5.3 通过 / 失败判定
- **通过标准**：
  1) 脚本退出码为 `0`
  2) 关键指标全部满足阈值（`rule_eval_p95_ms` / `dns_resolve_p95_ms` / `throughput_rps`）
- **失败判定**：
  1) 脚本退出码非 `0`
  2) 任一关键指标越阈值

---

## 6) 脚本接入指导（下一步）

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

## 7) 失败后处理建议（P4-1.C）

当回归失败（exit code != 0 或指标越阈）时：

1. **先定位再调阈值**
- 优先检查当次 `latest.json` 与最近 3 次 `history/*.json`，确认是否偶发抖动。
- 对应定位方向：
  - `rule_eval_p95_ms` 超阈：先看规则数量、匹配顺序、缓存命中
  - `dns_resolve_p95_ms` 超阈：先看 DNS 上游、缓存命中率、网络抖动
  - `throughput_rps` 低于阈值：先看 CPU 饱和、连接复用、锁竞争

2. **放宽阈值的前置条件**
- 只有在“可解释的环境变化”下才可临时放宽；
- 放宽必须记录原因、范围、回收时间（何时恢复原阈值）；
- 禁止一次性大幅放宽（遵循上文“调整上限”）。

3. **回归恢复路径**
- 修复后至少重跑 3 轮；
- 若恢复达标，再关闭失败告警并保留修复记录。

## 8) 验收对齐（P4-1.A / P4-1.C）

- [x] 定义 profiling 目标、采样口径、目录约定
- [x] 至少 3 个核心指标 + 阈值占位
- [x] 文档可直接指导脚本接入
- [x] 核心指标具备默认阈值占位 + 调整说明
- [x] 失败后处理建议可执行

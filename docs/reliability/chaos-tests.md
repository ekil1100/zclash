# Reliability / Chaos Tests（P4-2）

## P4-2B：24h 长稳测试计划（最小落地）

## 1) 测试输入

- 测试时长：连续 **24h**
- 配置输入：使用 `testdata/config/multi-proxy.yaml`
- 流量模型：
  - 常驻低压流量（模拟日常）
  - 每 10 分钟一次突发流量（短时高并发）
- 网络扰动（可选）：
  - DNS 抖动
  - 上游延迟波动

---

## 2) 监控指标（与 perf 字段兼容）

基础指标（沿用 perf 语义，避免冲突）：
- `rule_eval_p95_ms`
- `dns_resolve_p95_ms`
- `throughput_rps`
- `handshake_p95_ms`

长稳补充指标：
- `crash_count_24h`（24h 崩溃次数）
- `auto_recover_count_24h`（自动恢复次数）
- `max_recover_time_ms`（最大恢复耗时）

说明：
- 现有 perf 字段保持不变，新增长稳字段仅追加，不复用已有字段名。

---

## 3) 判定标准

通过（PASS）：
1. 24h 内 `crash_count_24h = 0`
2. 核心性能指标无持续性退化（连续 3 个采样窗口越阈值视为失败）
3. 若发生异常，恢复耗时 `max_recover_time_ms <= 30000`

失败（FAIL）：
1. 任意进程崩溃未恢复
2. 核心指标持续越阈值
3. 恢复耗时超过 30s 或恢复后功能不完整

---

## 4) 中断恢复策略

- 进程异常退出：
  1) 立即拉起（自动重启）
  2) 记录恢复起止时间
  3) 记录恢复后首个健康检查结果

- 外部中断（机器重启/网络断连）：
  1) 标记中断区间
  2) 恢复后继续计时并附注“外部中断”标签
  3) 最终报告区分“系统问题”与“环境问题”

---

## 5) 失败归档字段（最小）

当 FAIL 时，归档记录需至少包含：
- `run_id`
- `timestamp`
- `phase`（`24h-soak`）
- `status`（`PASS|FAIL`）
- `failed_fields[]`（失败字段名）
- `recover_actions[]`（已执行恢复动作）
- `note`

建议输出到：`docs/perf/reports/history/` 对应 run 文件，字段以追加方式扩展。

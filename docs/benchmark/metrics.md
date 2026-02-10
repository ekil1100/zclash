# Metrics Definition（Phase 0）

> 状态：DOING  
> 更新时间：2026-02-11 03:17 (GMT+8)

## 1. 指标总览

## 可用性
- `startup_time_ms`：进程启动到端口可连通
- `first_success_request_ms`：启动后首个成功请求耗时
- `success_rate`：请求成功率

## 正确性
- `rule_match_accuracy`：规则命中准确率
- `wrong_route_rate`：错误路由比例

## 性能
- `latency_p50_ms` / `latency_p95_ms`
- `throughput_rps`
- `cpu_avg_pct` / `cpu_peak_pct`
- `mem_avg_mb` / `mem_peak_mb`

## 稳定性
- `crash_count_24h` / `crash_count_72h`
- `mttr_ms`（平均恢复时长）
- `error_rate_drift`（长稳阶段错误率漂移）

## DNS
- `dns_resolve_p50_ms` / `dns_resolve_p95_ms`
- `dns_failure_rate`
- `dns_cache_hit_rate`

## 2. 统计口径

- 延迟类默认统计 `p50/p95`，必要时补充 `p99`
- 每个场景至少运行 3 轮，取中位结果并保留原始数据
- 统一测试环境（机器、网络、配置）后再做横向对比

## 3. 阶段目标（初稿，待基线实测后回填）

- CLI 启动到可用：目标 <= 基线
- 规则匹配准确率：目标 100%
- 高并发场景稳定性：目标 >= 基线
- 长稳崩溃次数：目标 <= 基线

## 4. 回填计划

1. 完成 baseline 实测后填入“当前值/基线值/目标值”
2. 在 `docs/benchmark/baseline.md` 建立指标对照表
3. 将关键阈值接入回归门禁

# TASKS.md — zclash 执行任务清单（基于 ROADMAP）

> 状态说明：`TODO` / `DOING` / `BLOCKED` / `DONE`
> 更新规则：每次推进后立即更新本文件（状态、负责人、备注、时间）。
> 强制要求：每个任务必须包含“验收标准（Acceptance Criteria）”，否则不得进入 `DOING`。

---

## 当前冲刺：Phase 0（基线与差距分析）

### P0-1 能力矩阵对比（mihomo/clash vs zclash）
- 状态：DOING
- 优先级：P0
- 负责人：Lan
- 输出：`docs/benchmark/baseline.md`
- 验收标准（Acceptance Criteria）：
  - [ ] 覆盖 CLI/API/TUI/协议/规则/DNS/观测 7 大维度
  - [ ] 每个维度包含“基线现状 + zclash 现状 + 差距等级 + 下一步建议”
  - [ ] 差距分级明确为 P0/P1/P2 并可追溯到 ROADMAP
- 子任务：
  - [x] 列出 mihomo/clash 功能矩阵（CLI/API/TUI/协议/规则/DNS/观测）
  - [x] 列出 zclash 当前能力矩阵（已实现/缺失/不稳定）
  - [x] 形成并排对比表（功能、体验、稳定性、性能）
  - [x] 标注“必补项/增强项/可延后项”
- 备注：已完成初版矩阵与分级标注，待与 gap-analysis 做最终对齐。

### P0-2 标准测试场景与样例集
- 状态：DONE
- 优先级：P0
- 负责人：Lan
- 输出：`docs/benchmark/scenarios.md`, `testdata/`
- 验收标准（Acceptance Criteria）：
  - [x] 覆盖启动、规则、切换、DNS、并发、长稳 6 类场景
  - [x] 每类场景都包含输入、验证点、输出指标
  - [x] `testdata/` 中至少落地最小配置与规则样例
- 子任务：
  - [x] 准备最小可运行配置样例（单节点、多节点、代理组）
  - [x] 准备规则样例（domain/ip-cidr/geo 类）
  - [x] 准备压力场景（高并发、多规则、DNS 抖动）
  - [x] 固化输入数据与期望输出
- 备注：已落地 `testdata/config/minimal.yaml`、`testdata/config/multi-proxy.yaml`、`testdata/rules/rule-matrix.yaml`。

### P0-3 北极星指标定义
- 状态：DONE
- 优先级：P0
- 负责人：Lan
- 输出：`docs/benchmark/metrics.md`
- 验收标准（Acceptance Criteria）：
  - [x] 指标覆盖可用性/正确性/性能/稳定性/DNS 五类
  - [x] 每类指标具备统计口径（含 p50/p95）
  - [x] 至少 5 项关键指标有“基线值/目标值”
- 子任务：
  - [x] 定义启动耗时、规则匹配延迟、吞吐、错误率、恢复时延
  - [x] 明确采样方法与统计口径（p50/p95）
  - [x] 明确基线值与阶段目标值
- 备注：已回填 6 项关键指标 baseline/target，后续按压测结果持续更新。

### P0-4 差距清单与优先级
- 状态：DONE
- 优先级：P0
- 负责人：Lan
- 输出：`docs/roadmap/gap-analysis.md`
- 验收标准（Acceptance Criteria）：
  - [x] 输出 P0/P1/P2 分级并给出判定依据
  - [x] 明确关键风险、依赖与缓解策略
  - [x] 明确 Phase 1 入口条件（可检查）
- 子任务：
  - [x] 汇总 P0-1/2/3 结果
  - [x] 给出优先级（P0/P1/P2）
  - [x] 给出风险与依赖
  - [x] 给出 Phase 1 入口条件
- 备注：`gap-analysis.md` 已完成与 baseline/metrics 最终对齐，Phase 1 入口条件可验收。

---

## 预备任务：Phase 1（CLI 直觉化）

### P1-1 CLI 命令模型统一
- 状态：TODO
- 优先级：P1
- 输出：`docs/cli/spec.md`
- 子任务：
  - [ ] 定义命令命名规范与层级结构
  - [ ] 统一 `start/stop/restart/status` 语义与输出
  - [ ] 增加 `--json` 输出规范
  - [ ] 错误输出格式统一（code/message/hint）

### P1-2 Profile/Proxy/Diag 命令完善
- 状态：TODO
- 优先级：P1
- 输出：CLI 子命令实现 + 文档
- 子任务：
  - [ ] `profile list/use/import/validate`
  - [ ] `proxy list/select/test`
  - [ ] `diag doctor`

---

## 预备任务：Phase 2（API 易用化）

### P2-1 API v1 资源模型
- 状态：TODO
- 优先级：P2
- 输出：`docs/api/openapi.yaml`
- 子任务：
  - [ ] runtime/profiles/proxies/connections/rules/metrics 资源定义
  - [ ] REST 与 WS 事件边界定义
  - [ ] 版本策略定义

### P2-2 错误码与测试
- 状态：TODO
- 优先级：P2
- 输出：`docs/api/error-codes.md` + 集成测试
- 子任务：
  - [ ] 错误码字典
  - [ ] 关键端点集成测试

---

## 预备任务：Phase 3（TUI 易用化）

### P3-1 信息架构重排
- 状态：TODO
- 优先级：P3
- 输出：`docs/tui/interaction.md`
- 子任务：
  - [ ] Overview/Proxies/Connections/Logs/Diagnose 五区布局
  - [ ] 全局快捷键统一
  - [ ] 首屏信息密度优化

### P3-2 核心交互增强
- 状态：TODO
- 优先级：P3
- 输出：`docs/tui/keymap.md` + 功能实现
- 子任务：
  - [ ] 代理组切换 + 延迟对比
  - [ ] 连接筛选/排序
  - [ ] 日志过滤
  - [ ] 重载反馈

---

## 预备任务：Phase 4（性能与稳定性）

### P4-1 Profiling 与性能回归
- 状态：TODO
- 优先级：P4
- 输出：`docs/perf/reports/`
- 子任务：
  - [ ] 热路径 profiling
  - [ ] 性能回归基线脚本
  - [ ] 回归门禁阈值

### P4-2 长稳与故障注入
- 状态：TODO
- 优先级：P4
- 输出：`docs/reliability/chaos-tests.md`
- 子任务：
  - [ ] 24h/72h 长稳
  - [ ] 故障注入与恢复验证
  - [ ] 热重载回滚验证

---

## 预备任务：Phase 5（兼容与生态）

### P5-1 配置兼容与迁移
- 状态：TODO
- 优先级：P5
- 输出：`docs/compat/mihomo-clash.md`, `tools/config-migrator/`
- 子任务：
  - [ ] 兼容层能力清单
  - [ ] migrator lint + autofix
  - [ ] 样例迁移验证

---

## 变更日志（实时更新）

- 2026-02-11 03:10（GMT+8）初始化 TASKS.md，按 ROADMAP 拆解任务。
- 2026-02-11 03:16（GMT+8）P0-1 状态更新为 DOING；初始化 `docs/benchmark/baseline.md` 初版能力矩阵草稿。
- 2026-02-11 03:17（GMT+8）P0-2/P0-3 状态更新为 DOING；新增 `docs/benchmark/scenarios.md` 与 `docs/benchmark/metrics.md` 初版。
- 2026-02-11 03:31（GMT+8）新增 `docs/roadmap/gap-analysis.md` 初稿；P0-4 更新为 DOING。
- 2026-02-11 03:32（GMT+8）为 P0-1~P0-4 补齐 Acceptance Criteria，并同步子任务完成度与备注。
- 2026-02-11 04:00（GMT+8）完成 P0-1 收尾：`baseline.md` 增加 必补/增强/可延后 + P0/P1/P2 分级标注；P0-1 最后子项勾选完成。
- 2026-02-11 04:09（GMT+8）完成 P0-2：落地 `testdata` 样例（minimal/multi-proxy/rule-matrix），P0-2 状态更新为 DONE。
- 2026-02-11 04:13（GMT+8）完成 P0-3：`metrics.md` 回填 6 项关键指标 baseline/target（含 p50/p95 口径），P0-3 状态更新为 DONE。
- 2026-02-11 04:25（GMT+8）完成 P0-4 收尾：`gap-analysis.md` 定稿（分级/风险依赖缓解/Phase 1 可检查入口条件），P0-4 状态更新为 DONE。

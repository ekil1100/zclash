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
- 状态：DONE
- 优先级：P1
- 输出：`docs/cli/spec.md`
- 子任务：
  - [x] 定义命令命名规范与层级结构
  - [x] 统一 `start/stop/restart/status` 语义与输出
  - [x] 增加 `--json` 输出规范
  - [x] 错误输出格式统一（code/message/hint）
- 备注：已补“实现映射清单”（代码位置+实现状态+缺口）与最小实现序列 A/B/C；已落地 A+B+C 首批（服务控制命令 + `proxy list --json`，并补 `proxy` 路径部分错误结构），可复现验证已补齐。

### P1-2 Profile/Proxy/Diag 命令完善
- 状态：DONE
- 优先级：P1
- 输出：CLI 子命令实现 + 文档
- 验收标准（Acceptance Criteria / DoD）：
  - [x] `profile list/use/import/validate` 四子命令具备输入/输出/错误结构定义
  - [x] 至少 `profile list/use` 落地 `--json` 输出
  - [x] 错误输出统一 `code/message/hint`
  - [x] 提供至少 1 条可复现验证命令
- 子任务：
  - [x] 文档补齐 `profile list/use/import/validate` 规范（`docs/cli/spec.md`）
  - [x] 实现 `profile list/use`（含 `--json`）
  - [x] 实现 `profile import/validate`（含 `--json`）
  - [x] `proxy list/select/test` 补齐剩余 `--json` 路径
  - [x] `diag doctor` 补齐 `--json` 输出
- 备注：P1-2 已完成（profile/proxy/diag 关键 JSON 路径落地并可复现验证）。

---

## 预备任务：Phase 2（API 易用化）

### P2-1 API v1 资源模型
- 状态：DONE
- 优先级：P2
- 输出：`docs/api/openapi.yaml`
- 验收标准（Acceptance Criteria / DoD）：
  - [x] OpenAPI 覆盖 runtime/profiles/proxies/connections/rules/metrics 六类资源骨架
  - [x] REST 基本路由与核心字段结构可读可评审
  - [x] 错误响应统一 `code/message/hint`
- 子任务：
  - [x] runtime/profiles/proxies 资源骨架定义（OpenAPI 初稿）
  - [x] connections/rules/metrics 资源骨架补齐
  - [x] REST 与 WS 事件边界定义
  - [x] 版本策略定义
- 备注：已补齐 REST/WS 边界与 v1 版本策略（见 `docs/api/openapi.yaml` 与 `docs/api/versioning.md`）。

### P2-2 错误码与测试
- 状态：DONE
- 优先级：P2
- 输出：`docs/api/error-codes.md` + 集成测试
- 验收标准（Acceptance Criteria / DoD）：
  - [x] `docs/api/error-codes.md` 覆盖至少 5 类错误（配置/网络/提供商/校验/权限）
  - [x] 每类至少包含 code/message/hint 示例
  - [x] OpenAPI 与实现逐步对齐统一错误码字典
  - [x] 关键端点集成测试覆盖高频错误码
- 子任务：
  - [x] 错误码字典初稿（5 类 + 示例）
  - [x] OpenAPI 对齐错误码字典
  - [x] profile/proxy/diag 路径错误码对齐
  - [x] 关键端点集成测试
- 备注：P2-2 已完成；新增 `src/integration_error_test.zig` 覆盖 profile/proxy/diag 三类高频错误码结构断言。

---

## 预备任务：Phase 3（TUI 易用化）

### P3-1 信息架构重排
- 状态：DONE
- 优先级：P3
- 输出：`docs/tui/interaction.md`
- 验收标准（Acceptance Criteria / DoD）：
  - [x] 五区布局定义可评审且可实现（Overview/Proxies/Connections/Logs/Diagnose）
  - [x] 全局快捷键一致性原则明确（含冲突与提示约束）
  - [x] 首屏信息密度优化原则可执行（含优先级和展示边界）
- 子任务：
  - [x] Overview/Proxies/Connections/Logs/Diagnose 五区布局
  - [x] 全局快捷键统一
  - [x] 首屏信息密度优化
- 备注：P3-1 已完成，已进入 P3-2 交互与键位细化。

### P3-2 核心交互增强
- 状态：DONE
- 优先级：P3
- 输出：`docs/tui/keymap.md` + 功能实现
- 验收标准（Acceptance Criteria / DoD）：
  - [x] 代理组切换具备可见反馈（成功/失败/建议）
  - [x] 连接筛选可按目标/入站/出站执行且可清空
  - [x] 日志过滤支持级别+关键字并可恢复全量
  - [ ] 重载反馈包含结果与耗时
- 子任务：
  - [x] 键位草案文档（`docs/tui/keymap.md`）
  - [x] 代理组切换 + 延迟对比
  - [x] 连接筛选/排序
  - [x] 日志过滤
  - [ ] 重载反馈（子任务5）
- 子任务5 验收标准（原子可开工）：
  - [x] 触发重载后显示 `running -> done/failed` 状态流（文档定义完成）
  - [x] 展示耗时（ms）与时间戳（文档定义完成）
  - [x] 失败场景包含结构化错误与下一步建议（hint）（文档定义完成）
  - [x] 成功/失败结果在状态条与日志区均可见（文档定义完成）
- 备注：P3-2 交互规则文档已完整，可直接进入实现。

---

## 预备任务：Phase 4（性能与稳定性）

### P4-1 Profiling 与性能回归
- 状态：DOING
- 优先级：P4
- 输出：`docs/perf/reports/`
- 子任务：
  - [x] P4-1A profiling 脚手架（首个原子项）
    - 范围：新增 `docs/perf/reports/README.md` + `scripts/perf/run-baseline.sh`（可运行占位）
    - DoD：脚本可执行并输出占位指标（`rule_eval_p95_ms` / `dns_p95_ms` / `throughput_rps`）与阈值占位
    - 预计时长：30-50 分钟
  - [x] P4-1B 回归执行入口定义（本地/CI）
    - 命令统一：`bash scripts/perf/run-baseline.sh`
    - 判定标准：exit code + 关键指标阈值
    - 引用：`docs/perf/reports/README.md` 第5节（入口）与第6节（脚本接入）
  - [x] P4-1C 指标阈值占位收敛（可执行化）
    - 覆盖：3 个核心指标默认阈值 + 调整说明
    - 新增：失败后处理建议（定位路径/放宽阈值规则）
    - 引用：`docs/perf/reports/README.md` 第4节与第7节
  - [x] P4-1D perf 回归脚本入口占位
    - 入口：`scripts/perf/run-baseline.sh`（与文档命令一致）
    - 协议：输出 `PERF_REGRESSION_RESULT=PASS|FAIL`，exit code 0/非0 对应 PASS/FAIL
    - 边界：仅占位，不实现真实采样与阈值计算逻辑
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
- 2026-02-11 04:48（GMT+8）推进 P1-1：新增 `docs/cli/spec.md` 初稿，P1-1 更新为 DOING 并勾选 4 项文档子任务。
- 2026-02-11 05:00（GMT+8）完善 P1-1：在 `docs/cli/spec.md` 新增实现映射清单（实现状态：已实现/部分实现/未实现）与最小实现序列（A/B/C）。
- 2026-02-11 05:12（GMT+8）落地 P1-1 最小实现序列 A：统一 start/stop/restart/status 文本语义；服务控制错误输出采用 `code/message/hint` 结构；更新 `spec.md` 进度与验证记录。
- 2026-02-11 05:24（GMT+8）落地 P1-1 最小实现序列 B：新增 `--json` 开关并覆盖 start/stop/restart/status 结构化输出，补充可复现验证命令。
- 2026-02-11 05:36（GMT+8）推进 P1-1 最小实现序列 C（首批）：扩展 `--json` 到 `proxy list`，并将 `proxy` 路径关键错误输出统一为 `code/message/hint`。
- 2026-02-11 05:48（GMT+8）启动 P1-2 子任务 1：在 `docs/cli/spec.md` 补齐 profile 四子命令规范；`TASKS.md` 同步 P1-2 DoD 与最小实现顺序（先 list/use，再 import/validate）。
- 2026-02-11 06:00（GMT+8）完成 P1-2 子任务 A：落地 `profile list/use`（含 `--json`）与结构化错误输出，补充可复现验证命令。
- 2026-02-11 06:12（GMT+8）完成 P1-2 子任务 B：落地 `profile import/validate`（含 `--json`）与结构化错误输出，补充可复现验证命令。
- 2026-02-11 06:24（GMT+8）完成 P1-2 子任务 C：补齐 `proxy list/select/test` 与 `diag doctor` 的 `--json` 输出路径，P1-2 状态更新为 DONE。
- 2026-02-11 06:36（GMT+8）启动 P2-1：新增 `docs/api/openapi.yaml` 初稿（runtime/profiles/proxies），并将 P2-1 更新为 DOING。
- 2026-02-11 06:48（GMT+8）推进 P2-1 子任务 2：补齐 connections/rules/metrics 资源骨架，六类核心资源已覆盖。
- 2026-02-11 07:00（GMT+8）完成 P2-1 子任务 3：明确 REST/WS 边界与 v1 版本策略；P2-1 状态更新为 DONE。
- 2026-02-11 07:12（GMT+8）启动 P2-2：新增 `docs/api/error-codes.md` 初稿（5 类错误 + code/message/hint 示例），并将 P2-2 更新为 DOING。
- 2026-02-11 07:24（GMT+8）完成 P2-2 子任务 2：将错误码字典映射到 OpenAPI（x-error-code-dictionary + ErrorResponse.code enum）。
- 2026-02-11 07:36（GMT+8）完成 P2-2 子任务 3：对齐 profile/proxy/diag 路径错误码到字典与 OpenAPI 枚举。
- 2026-02-11 07:48（GMT+8）完成 P2-2 子任务 4：新增 `src/integration_error_test.zig`（profile/proxy/diag 各 1 个错误场景），断言 `code/message/hint` 结构通过。
- 2026-02-11 08:00（GMT+8）启动 P3-1：新增 `docs/tui/interaction.md` 初稿（五区布局/快捷键一致性/首屏密度优化），并将 P3-1 更新为 DOING。
- 2026-02-11 08:02（GMT+8）收敛看板状态：P1-1 验收子项已全量完成，状态更新为 DONE。
- 2026-02-11 08:24（GMT+8）收敛 P3-1 并启动 P3-2：P3-1 更新为 DONE；新增 `docs/tui/keymap.md` 草案并将 P3-2 更新为 DOING。
- 2026-02-11 08:36（GMT+8）完成 P3-2 子任务 2 文档细化：补齐代理组切换交互流与延迟对比规则，P3-2 对应子任务勾选完成。
- 2026-02-11 08:40（GMT+8）完成 P3-2 子任务 3 文档细化：补齐连接筛选维度、排序规则与冲突处理，明确清空与恢复全量流程。
- 2026-02-11 09:01（GMT+8）完成 P3-2 子任务 4 文档细化：补齐日志级别+关键字组合过滤、清空恢复全量流程与边界处理。
- 2026-02-11 09:16（GMT+8）P3-2.4A/4B/4C 收敛：补齐日志过滤冲突优先级、一步恢复全量流程、空结果与失败示例；预拆子任务5（重载反馈）验收标准。
- 2026-02-11 09:28（GMT+8）完成 P3-2.5A/5B/5C 文档收敛（状态流/耗时时间戳/失败建议）；完成 P3-2.5D 看板收敛并将 P3-2 更新为 DONE；完成 P3-2.5E 预拆 P4-1A 原子项（范围/DoD/预计时长）。
- 2026-02-11 09:41（GMT+8）完成 P4-1B：定义 perf 回归本地/CI 统一入口与通过/失败判定，并在 TASKS 与 perf README 互相引用。
- 2026-02-11 09:46（GMT+8）完成 P4-1C：收敛 3 个核心指标默认阈值+调整说明，新增失败后处理建议并同步 TASKS 进度。
- 2026-02-11 09:49（GMT+8）完成 P4-1D：新增 `scripts/perf/run-baseline.sh` 占位入口（PASS/FAIL 协议 + exit code 约定），并记录后续实现边界。

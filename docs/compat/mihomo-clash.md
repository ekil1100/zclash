# zclash 兼容层能力清单（mihomo/clash）

> 状态：Draft v0.1（P5-1A）

## 1) 配置解析与基础结构

- 基础配置字段（port/socks-port/mixed-port/mode/log-level）: **已支持**（P0）
- DNS 基础字段（enable/nameserver/fallback）: **部分支持**（P0）
- Profile 多配置切换: **已支持**（P0）
- 实验/扩展字段透传: **未支持**（P2）

## 2) 代理与代理组

- Proxy 基础节点类型（常见协议）: **部分支持**（P0）
- Proxy Group 基本策略组（select/url-test/fallback）: **部分支持**（P0）
- 组内延迟测试与切换反馈: **部分支持**（P1）
- 复杂 provider 组合策略: **未支持**（P2）

## 3) 规则系统

- 基础规则匹配（domain/ip-cidr 等）: **已支持**（P0）
- 规则集（rule-provider）远程更新: **部分支持**（P1）
- 规则冲突诊断可视化: **未支持**（P2）

## 4) API / 控制面兼容

- Runtime/Profile/Proxy 基础 API: **已支持**（P0）
- 连接/规则/指标 API v1: **已支持**（P0）
- 错误结构（code/message/hint）: **已支持**（P0）
- 面板生态完全兼容（第三方面板零改造）: **未支持**（P2）

## 5) CLI / TUI 体验兼容

- CLI 核心命令（start/stop/restart/status）: **已支持**（P0）
- profile/proxy/diag + `--json`: **已支持**（P0）
- TUI 信息架构/键位一致性: **部分支持**（P1）
- 高级排障视图（全链路追踪）: **未支持**（P2）

## 6) 稳定性与运维

- 24h/72h 长稳执行入口: **已支持**（P1）
- 故障注入执行框架: **已支持**（P1）
- 热重载回滚执行链路: **部分支持**（P1）
- 自动化门禁（CI 强约束）: **部分支持**（P1）

---

## 优先级建议（P0/P1/P2）

### P0（必须优先）
1. 补齐 DNS 字段兼容缺口（与主流配置语义对齐）
2. 补齐代理组核心策略与边界行为一致性
3. 保持 API/CLI 错误契约稳定（避免生态接入回归）

### P1（体验增强）
1. 完成 rule-provider 更新链路与可观测反馈
2. 完成热重载回滚从“可执行”到“可门禁”
3. 完成 TUI 交互闭环（筛选、日志、重载反馈）

### 兼容规则声明（用于自动对账）
- `PORT_TYPE_INT`
- `LOG_LEVEL_ENUM`
- `PROXY_GROUP_TYPE_CHECK`

### P2（生态扩展）
1. 实验字段透传与高级 provider 组合
2. 第三方面板深度兼容层
3. 高级排障与冲突可视化

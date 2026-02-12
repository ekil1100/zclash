# zclash 兼容层能力清单（mihomo/clash）

> 状态：Draft v0.1（P5-1A）

## 1) 配置解析与基础结构

- 基础配置字段（port/socks-port/mixed-port/mode/log-level）: **已支持**（P0）
- DNS 基础字段（enable/nameserver/fallback）: **部分支持**（P0）

#### DNS 字段映射表（设计文档，P7-2B-prep）

| mihomo/clash 字段 | zclash 对应 | 状态 | 迁移规则 |
|---|---|---|---|
| `dns.enable` | `dns.enable` (bool) | 已支持 | DNS_FIELD_CHECK: 缺失时 warn + suggested=true |
| `dns.nameserver` | `dns.nameserver` (string[]) | 已支持 | DNS_FIELD_CHECK: 空数组时 error + hint |
| `dns.fallback` | `dns.fallback` (string[]) | 部分支持 | DNS_FIELD_CHECK: 缺失时 info（可选字段） |
| `dns.enhanced-mode` | 不支持 | 未支持 | DNS_FIELD_CHECK: 出现时 warn + hint="zclash 暂不支持 enhanced-mode，将忽略" |
| `dns.fallback-filter` | 不支持 | 未支持 | DNS_FIELD_CHECK: 出现时 info + hint="高级过滤暂不支持" |

**DNS_FIELD_CHECK 规则设计**：
- 输入：YAML 配置文件中 `dns:` 段
- 触发条件：
  - `dns.enable` 缺失或非 bool → warn, fixable=false, suggested=true
  - `dns.nameserver` 空或缺失 → error, fixable=false, hint="至少配置一个 nameserver"
  - `dns.enhanced-mode` 出现 → warn, fixable=false, hint="zclash 忽略此字段"
- 输出：标准 issues 数组，与 R1/R2/R3 口径一致
- 修复动作：仅提示，不自动修改（fixable=false）

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
- `DNS_FIELD_CHECK`
- `DNS_NAMESERVER_FORMAT`
- `PROXY_GROUP_EMPTY_PROXIES`
- `TUN_ENABLE_CHECK`
- `EXTERNAL_CONTROLLER_FORMAT`
- `ALLOW_LAN_BIND_CONFLICT`
- `RULE_PROVIDER_REF_CHECK`
- `PROXY_NODE_FIELDS_CHECK`
- `SS_CIPHER_ENUM_CHECK`
- `VMESS_UUID_FORMAT_CHECK`
- `MIXED_PORT_CONFLICT_CHECK`
- `MODE_ENUM_CHECK`
- `PROXY_NAME_UNIQUENESS_CHECK`
- `PORT_RANGE_CHECK`

### P2（生态扩展）
1. 实验字段透传与高级 provider 组合
2. 第三方面板深度兼容层
3. 高级排障与冲突可视化

---

## 迁移边界：不能迁的场景与绕行建议

以下场景在 zclash 当前版本中**无法自动迁移**，需用户手动处理。

### 1. `enhanced-mode: fake-ip` / `redir-host`

**现象**：mihomo/clash 支持 `dns.enhanced-mode` 实现 fake-ip 或 redir-host 透明代理模式。  
**zclash 状态**：不支持，字段会被忽略。  
**影响**：依赖 fake-ip 的透明代理场景无法工作。  
**绕行**：
- 改用 SOCKS5/HTTP 显式代理模式（配置浏览器/系统代理）
- 若必须透明代理，暂继续使用 mihomo，等待 zclash 后续支持

### 2. `rule-provider` 远程规则集自动更新

**现象**：mihomo/clash 支持 `rule-providers` 从远程 URL 拉取规则集并定时更新。  
**zclash 状态**：配置可解析但远程更新链路未完整实现。  
**影响**：规则集不会自动刷新，停留在初始下载版本。  
**绕行**：
- 手动定期下载规则文件放到本地路径
- 用 cron 脚本定期 `curl` 更新 + `zclash restart`

### 3. 复杂 `proxy-provider` 组合策略

**现象**：mihomo 支持通过 `proxy-providers` 从订阅 URL 动态拉取节点并按策略组合。  
**zclash 状态**：不支持 proxy-provider，节点必须在配置文件中静态声明。  
**影响**：多订阅聚合、节点动态更新场景不可用。  
**绕行**：
- 使用 `zclash config download <url>` 手动更新订阅
- 写脚本定期下载订阅 → 合并节点 → 写入配置 → `zclash restart`

### 4. 第三方面板（Yacd/Razord）完全兼容

**现象**：mihomo/clash 的 API 被 Yacd 等面板深度依赖（WebSocket 实时推送、特定字段格式）。  
**zclash 状态**：REST API 基础资源可用，但 WebSocket 推送和部分面板专用字段未实现。  
**影响**：面板可能部分功能不可用（实时流量图、连接断开等）。  
**绕行**：
- 使用 zclash 内置 TUI 查看状态
- 使用 `zclash doctor` / `zclash status` CLI 命令

### 5. `tun` 模式透明代理

**现象**：mihomo 支持 `tun` 模式实现系统级透明代理。  
**zclash 状态**：不支持。  
**影响**：无法实现系统全局代理（不经过浏览器/应用代理设置）。  
**绕行**：
- 使用系统代理设置指向 zclash 的 HTTP/SOCKS5 端口
- macOS: 系统偏好设置 → 网络 → 代理

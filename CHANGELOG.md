# Changelog

## v1.0.0 (准备中)

### 里程碑总览

从 P0（基线分析）到 P9（GA 准入验收），历经 10 个阶段，完成核心代理工具的全链路建设。

### Phase 0 — 基线与差距分析
- 建立 mihomo/clash 能力矩阵对比（CLI/API/TUI/协议/规则/DNS/观测 7 大维度）
- 输出差距清单与 P0/P1/P2 优先级分级
- 确立北极星指标与采样方法

### Phase 1 — CLI 直觉化
- 冻结核心命令语义（start/stop/status/proxy/profile/config/test/doctor）
- 统一 `--json` 输出契约（`{ok, data/error}` 结构）
- 定义错误输出规范（code/message/hint 三字段）

### Phase 2 — API v1 锁定
- REST API 6 类资源模型（runtime/profiles/proxies/connections/rules/metrics）
- OpenAPI 文档与错误码体系
- 版本化策略（`/v1/` 前缀）

### Phase 3 — 文档闭环
- TUI 信息架构与快捷键规范
- CLI spec 完整文档

### Phase 4 — 性能与稳定性
- 性能回归门禁（baseline + threshold + 自动校验）
- 稳定性链路（24h/72h soak 脚手架、故障注入框架、热重载回滚）
- 历史数据归档与清理策略

### Phase 5 — 兼容与迁移
- mihomo/clash 兼容层能力清单
- 配置迁移工具（lint + autofix）
- 11 条迁移规则：
  - R1 PORT_TYPE_INT（端口字符串→整数）
  - R2 LOG_LEVEL_ENUM（日志级别枚举校验）
  - R3 PROXY_GROUP_TYPE_CHECK（代理组类型校验）
  - R4 DNS_FIELD_CHECK（DNS 字段完整性）
  - R5 DNS_NAMESERVER_FORMAT（nameserver 格式校验）
  - R6 PROXY_GROUP_EMPTY_PROXIES（空代理组检测）
  - R7 TUN_ENABLE_CHECK（不支持的 tun 模式提示）
  - R8 EXTERNAL_CONTROLLER_FORMAT（控制器地址格式）
  - R9 ALLOW_LAN_BIND_CONFLICT（LAN 与绑定地址矛盾）
  - R10 RULE_PROVIDER_REF_CHECK（规则集引用校验）
  - R11 PROXY_NODE_FIELDS_CHECK（节点必填字段校验）
- 5 个迁移边界场景文档（含绕行建议）

### Phase 6 — 安装链路
- 一键安装/验证/升级/回滚链路（`oc-run.sh`）
- 统一机读字段契约（INSTALL_RESULT/ACTION/REPORT/FAILED_STEP/NEXT_STEP/SUMMARY）
- 失败提示中文化 + next-step 词典
- Beta 检查清单自动执行器
- 证据归档自动化（history/index/timeline）
- 跨环境验证矩阵（正常/异常/冲突路径）
- 3-step smoke 公开摘要导出

### Phase 7 — 试用与 1.1 并行
- 3 分钟快速启动指南
- 试用反馈模板
- 一键健康检查（安装/版本/配置/网络 4 项诊断）
- TUI 日志级别三色高亮（error/warn/info）
- `zclash doctor --json` 增强（version/config_path/network_ok/proxy_reachable/config_errors/config_warnings/migration_hints）
- 1.1 并行泳道建立

### Phase 8 — Beta 准入基础设施
- Beta gate 一键自检（build/test/migrator/install 4 项）
- 三合一总验证脚本（install+migrator+beta-gate）
- CI pipeline 完善（build → test → migrator → install → full-validation）
- 1.0 准入条件逐项审计

### Phase 9 — GA 准入验收
- 真实 24h/72h soak runner（进程监控 + 端口检测 + 崩溃自动重启）
- 72h soak PASS 归档
- **1.0 准入条件 8/8 全部满足**

### 技术指标
- 协议支持：HTTP/SOCKS5/混合端口/Shadowsocks/VMess/Trojan/VLESS
- 规则引擎：12 种规则类型 + no-resolve
- 代理组策略：select/url-test/fallback/load-balance/relay
- 迁移规则：11 条（全部回归通过）
- 安装链路回归：全链路 PASS
- CI：build + test + migrator + install + full-validation

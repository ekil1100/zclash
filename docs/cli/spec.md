# CLI Spec（Phase 1 初稿）

> 状态：DRAFT  
> 更新时间：2026-02-11 04:48 (GMT+8)

## 1. 目标

统一 zclash CLI 的命令模型与输出契约，保证：
- 人类使用直觉一致
- 自动化脚本可稳定依赖
- 错误可定位且可操作

---

## 2. 命名规范

### 2.1 总体规则
- 优先使用：`zclash <resource> <action>`
- 对全局动作保留短命令：`zclash start|stop|restart|status`
- 命令、参数统一使用 `kebab-case`
- 避免同义重复命令（只保留一个主命令，必要时提供 alias）

### 2.2 资源命名
- `profile`：配置文件与激活配置管理
- `proxy`：代理组与节点操作
- `rule`：规则检查与测试
- `diag`：诊断与健康检查

### 2.3 alias 约定
- `list` 可提供 `ls`
- alias 仅作为便捷入口，不单独扩展语义

---

## 3. 命令层级

## 3.1 L0（全局控制）
- `zclash start [-c <config>]`
- `zclash stop`
- `zclash restart [-c <config>]`
- `zclash status`

## 3.2 L1（资源控制）
- `zclash profile <action>`
- `zclash proxy <action>`
- `zclash rule <action>`
- `zclash diag <action>`

## 3.3 L2（示例动作）
- `zclash profile list|use|import|validate`
- `zclash proxy list|select|test`
- `zclash rule inspect|test`
- `zclash diag doctor`

---

## 4. start/stop/restart/status 统一语义

### `start`
- 语义：启动服务（若已启动则返回已运行状态，不重复拉起）
- 成功：返回运行中状态 + 关键端口/配置摘要

### `stop`
- 语义：停止服务（若未运行，返回已停止状态）
- 成功：确认进程已退出

### `restart`
- 语义：先 stop 再 start；中间失败必须显式报错
- 成功：返回新进程状态与配置摘要

### `status`
- 语义：只读查询，不改变状态
- 成功：返回运行状态、PID、端口、配置来源、最近错误（若有）

---

## 5. `--json` 输出规范

所有可读命令应支持 `--json`。

### 5.1 顶层结构
```json
{
  "ok": true,
  "data": {},
  "meta": {
    "command": "zclash status",
    "timestamp": "2026-02-11T04:48:00+08:00"
  }
}
```

### 5.2 约束
- `ok=true` 时必须返回 `data`
- `ok=false` 时必须返回 `error`
- 字段命名统一 `snake_case` 或 `camelCase`（二选一，全局一致；当前建议 `snake_case`）

---

## 6. 错误输出格式（code/message/hint）

### 6.1 标准结构
```json
{
  "ok": false,
  "error": {
    "code": "CONFIG_NOT_FOUND",
    "message": "config file not found: /path/to/config.yaml",
    "hint": "run `zclash profile list` to view available profiles"
  },
  "meta": {
    "command": "zclash start -c /path/to/config.yaml",
    "timestamp": "2026-02-11T04:48:00+08:00"
  }
}
```

### 6.2 规则
- `code`：稳定、可机器判断（全大写 + 下划线）
- `message`：面向人类，解释发生了什么
- `hint`：给出下一步可执行动作

---

## 7. 验收标准（P1-1）

- [x] 命令命名规范与层级结构清晰
- [x] `start/stop/restart/status` 语义统一
- [x] `--json` 输出有统一顶层结构
- [x] 错误输出采用 `code/message/hint`
- [ ] 与实现逐项对齐并补充示例输出（下一步）

---

## 8. 实现映射清单（代码位置 + 缺口）

| 规范项 | 代码位置 | 现状 | 说明 |
|---|---|---|---|
| `start` 语义统一 | `src/main.zig`（命令分发）、`src/daemon.zig`（`startDaemon`） | 部分实现 | 已支持启动与配置参数；“已运行时返回统一结构”尚未标准化 |
| `stop` 语义统一 | `src/main.zig`、`src/daemon.zig`（`stopDaemon`） | 部分实现 | 已支持停止；未运行时反馈仍偏文本化，缺统一状态结构 |
| `restart` 语义统一 | `src/main.zig`（先 stop 后 start） | 部分实现 | 流程存在，但失败路径与输出契约未统一 |
| `status` 语义统一 | `src/main.zig`（status 分支）、`src/daemon.zig`（状态查询与日志） | 部分实现 | 有状态查询能力；输出字段（PID/配置来源/错误）未统一结构化 |
| `--json` 输出规范 | `src/main.zig`（当前未统一处理） | 未实现 | CLI 尚无统一 `--json` 解析与顶层响应结构 |
| 错误格式 `code/message/hint` | `src/main.zig`、`src/daemon.zig`、`src/proxy_cli.zig`、`src/doctor_cli.zig` | 未实现 | 当前以 `std.debug.print` 文本为主，缺稳定错误码与 hint |

### 8.1 缺口结论
- 当前 CLI 主流程已可用，但“**契约化输出**”尚未落地。
- P1-1 的核心缺口在于：
  1) 统一 `--json` 输出层；
  2) 统一错误结构（code/message/hint）；
  3) 将 start/stop/restart/status 的状态语义落成稳定字段。

## 9. 下一步最小实现序列（原子可提交）

1. **原子任务 A：统一参数入口（`--json` 开关）**  
   在 `main.zig` 增加全局 `--json` 解析与透传，不改业务逻辑，仅建立结构化输出开关。

2. **原子任务 B：状态命令结构化输出**  
   先改 `status` 命令：文本输出保留，新增 `--json` 下的标准结构（`ok/data/meta`）。

3. **原子任务 C：错误输出标准化最小闭环**  
   先覆盖 start/stop/restart/status 四命令，把核心错误统一为 `code/message/hint`；其它命令后续跟进。

## 10. 下一步

1. 先实施原子任务 A（不改变现有可用行为）；
2. 再实施原子任务 B（先把 status 做成样板）；
3. 最后实施原子任务 C，并补 TDD/BDD 验收用例。

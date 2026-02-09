# zclash Agents Architecture

本文档描述 zclash 的核心组件（Agents）及其职责。

## 架构概览

```
┌─────────────────────────────────────────────────────────────┐
│                         CLI Layer                           │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────────────┐ │
│  │  help   │  │  tui    │  │  start  │  │  config         │ │
│  └─────────┘  └─────────┘  └─────────┘  └─────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      Core Layer                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │   Config    │  │   Daemon    │  │   TUI Manager       │  │
│  │  (config)   │  │  (daemon)   │  │    (tui)            │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     Proxy Layer                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────────┐  │
│  │  HTTP    │  │  SOCKS5  │  │  Mixed   │  │  Outbound  │  │
│  │  Proxy   │  │  Proxy   │  │  Proxy   │  │  Manager   │  │
│  └──────────┘  └──────────┘  └──────────┘  └────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Protocol Layer                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────────┐  │
│  │Shadowsocks│  │  VMess   │  │  Trojan  │  │   VLESS    │  │
│  └──────────┘  └──────────┘  └──────────┘  └────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Infrastructure                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────────┐  │
│  │   DNS    │  │   Rule   │  │   API    │  │   Crypto   │  │
│  │  Client  │  │  Engine  │  │  Server  │  │   (TLS)    │  │
│  └──────────┘  └──────────┘  └──────────┘  └────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## CLI Agents

### 1. Help Agent
- **文件**: `main.zig` (printHelp, printConfigHelp)
- **职责**: 显示帮助信息
- **命令**: `zclash help`, `zclash config`

### 2. TUI Agent
- **文件**: `main.zig` (runProxy with use_tui=true), `tui.zig`
- **职责**: 启动交互式终端界面
- **命令**: `zclash tui [-c config]`
- **交互**: 键盘快捷键、鼠标操作

### 3. Daemon Agent
- **文件**: `daemon.zig`, `main.zig` (start/stop/restart)
- **职责**: 后台服务管理
- **命令**: 
  - `zclash start [-c config]`
  - `zclash stop`
  - `zclash restart [-c config]`
  - `zclash status`
  - `zclash log [-n lines] [--no-follow]`

### 4. Config Agent
- **文件**: `main.zig` (config subcommand), `config.zig`
- **职责**: 配置管理
- **命令**:
  - `zclash config list|ls`
  - `zclash config download <url> [-n name] [-d]`
  - `zclash config use <configname>`

---

## Core Agents

### 1. Config Agent
- **文件**: `config.zig`
- **职责**:
  - YAML 配置解析
  - 配置验证
  - 默认配置路径管理
  - 配置下载和切换
- **关键函数**:
  - `load()` - 从文件加载配置
  - `loadDefault()` - 加载默认配置
  - `downloadConfig()` - 从 URL 下载配置
  - `switchConfig()` - 切换配置
  - `listConfigs()` - 列出所有配置

### 2. Config Validator Agent
- **文件**: `config_validator.zig`
- **职责**:
  - 端口范围验证
  - 代理节点字段验证
  - 代理组引用验证
  - 规则验证
  - 重复名称检查
- **关键函数**:
  - `validate()` - 执行完整验证
  - `printResult()` - 输出验证结果

### 3. Daemon Agent
- **文件**: `daemon.zig`
- **职责**:
  - PID 文件管理
  - 进程守护
  - 日志轮转
  - 服务状态检查
- **关键函数**:
  - `startDaemon()` - 启动守护进程
  - `stopDaemon()` - 停止服务
  - `getStatus()` - 获取状态
  - `viewLog()` - 查看日志

### 4. TUI Manager Agent
- **文件**: `tui.zig`
- **职责**:
  - 终端界面渲染
  - 用户输入处理
  - 标签页管理
  - 延迟测试触发
  - 配置重载触发
- **标签页**:
  - Groups - 代理组列表
  - Proxies - 节点列表（带延迟显示）
  - Connections - 活跃连接
  - Logs - 系统日志

---

## Proxy Agents

### 1. HTTP Proxy Agent
- **文件**: `proxy/http.zig`
- **职责**:
  - HTTP/HTTPS 代理服务
  - CONNECT 方法支持
  - 普通 HTTP 代理
- **端口**: 可配置 (默认 7890)

### 2. SOCKS5 Proxy Agent
- **文件**: `proxy/socks5.zig`
- **职责**:
  - SOCKS5 协议实现
  - 无认证/用户名密码认证
  - IPv4/IPv6/域名解析
- **端口**: 可配置 (默认 7891)

### 3. Mixed Proxy Agent
- **文件**: `proxy/mixed.zig`
- **职责**:
  - HTTP + SOCKS5 共用端口
  - 协议自动识别
- **端口**: 可配置 (默认 7892)

### 4. Outbound Manager Agent
- **文件**: `proxy/outbound/manager.zig`
- **职责**:
  - 出站连接管理
  - 代理节点选择
  - 连接池管理
- **子模块**:
  - `shadowsocks.zig` - Shadowsocks 出站

---

## Protocol Agents

### 1. Shadowsocks Agent
- **文件**: `protocol/`, `proxy/outbound/shadowsocks.zig`
- **职责**:
  - Shadowsocks 协议实现
  - 加密/解密
  - 支持算法: AES-GCM, ChaCha20-Poly1305

### 2. VMess Agent
- **文件**: `protocol/vmess.zig`
- **职责**:
  - VMess 协议实现
  - UUID 认证
  - AlterID 支持

### 3. Trojan Agent
- **文件**: `protocol/trojan.zig`
- **职责**:
  - Trojan 协议实现
  - TLS 伪装
  - 密码认证

### 4. VLESS Agent
- **职责**:
  - VLESS 协议实现（基础 TCP）
  - UUID 认证
- **状态**: TCP 最小实现

---

## Infrastructure Agents

### 1. DNS Client Agent
- **文件**: `dns/client.zig`, `dns/protocol.zig`
- **职责**:
  - DNS 查询（UDP/TCP）
  - DNS 缓存
  - 域名解析

### 2. Rule Engine Agent
- **文件**: `rule/engine.zig`
- **职责**:
  - 规则匹配引擎
  - 规则类型: DOMAIN, DOMAIN-SUFFIX, DOMAIN-KEYWORD, IP-CIDR, GEOIP, etc.
  - 优先级处理

### 3. API Server Agent
- **文件**: `api/server.zig`
- **职责**:
  - REST API 服务
  - 端口: 9090 (可配置)
  - 提供代理状态查询

### 4. Crypto Agent
- **文件**: `crypto/tls.zig`, `crypto/aead.zig`
- **职责**:
  - TLS 连接
  - AEAD 加密
  - 证书处理

---

## 数据流

### 1. 请求处理流程

```
Client Request
    │
    ▼
┌─────────────┐
│ HTTP/SOCKS  │ ◄── Proxy Agents
│   Proxy     │
└─────────────┘
    │
    ▼
┌─────────────┐
│ Rule Engine │ ◄── 匹配规则
└─────────────┘
    │
    ▼
┌─────────────┐
│   Outbound  │ ◄── 选择代理节点
│   Manager   │
└─────────────┘
    │
    ▼
┌─────────────┐
│  Protocol   │ ◄── 协议处理
│   Layer     │
└─────────────┘
    │
    ▼
Target Server
```

### 2. 配置管理流程

```
User Command
    │
    ├── config download ──┬──► HTTP Client ──► Save to ~/.config/zclash/
    │                     │
    ├── config use ───────┼──► Create symlink config.yaml ──► Reload
    │                     │
    └── config list ──────┴──► Scan directory ──► Display
```

### 3. 服务管理流程

```
User Command
    │
    ├── start ────┬──► Fork ──► Daemonize ──► Run Proxy ──► Write PID
    │             │
    ├── stop ─────┼──► Read PID ──► Kill Process ──► Remove PID file
    │             │
    ├── restart ──┼──► Stop ──► Start
    │             │
    ├── status ───┼──► Read PID ──► Check process ──► Display status
    │             │
    └── log ──────┴──► Open log file ──► Tail -f (or display N lines)
```

---

## 配置路径

### 默认配置搜索顺序
1. `~/.config/zclash/config.yaml` (当前激活配置)
2. `~/.zclash/config.yaml`
3. `./config.yaml` (当前目录)
4. 内置默认配置

### 配置存储目录
- **Configs**: `~/.config/zclash/`
- **Logs**: `~/.local/share/zclash/zclash.log` 或 `/tmp/zclash.log`
- **PID**: `$XDG_RUNTIME_DIR/zclash.pid` 或 `/tmp/zclash.pid`

---

## 扩展点

### 添加新协议
1. 在 `protocol/` 创建新文件
2. 实现协议握手和转发逻辑
3. 在 `config.zig` 添加配置解析
4. 在 `config_validator.zig` 添加验证
5. 在 `proxy/outbound/manager.zig` 集成

### 添加新规则类型
1. 在 `rule/engine.zig` 添加 RuleType
2. 实现匹配逻辑
3. 在 `config.zig` 添加解析
4. 在 `config_validator.zig` 添加验证

### 添加新 CLI 命令
1. 在 `main.zig` 添加命令解析
2. 实现处理函数
3. 更新 `printHelp()` 帮助文本
4. 更新 README.md

---

## 技术栈

- **语言**: Zig 0.15.0+
- **构建**: build.zig
- **测试**: Zig 内置测试框架
- **终端**: 自研 TUI (基于 ANSI escape codes)
- **网络**: 异步 I/O, 基于事件循环
- **内存**: 手动管理, GPA (General Purpose Allocator)

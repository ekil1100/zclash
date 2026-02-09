# zclash

<p align="center">
  <strong>用 Zig 语言实现的高性能代理工具</strong><br>
  兼容 Clash 配置格式 | 现代化 TUI | 零依赖
</p>

<p align="center">
  <a href="#功能特性">功能特性</a> •
  <a href="#快速开始">快速开始</a> •
  <a href="#tui-界面">TUI 界面</a> •
  <a href="#配置说明">配置说明</a>
</p>

---

## 功能特性

### 🚀 代理协议
- [x] HTTP/HTTPS 代理 (CONNECT + 普通 HTTP)
- [x] SOCKS5 代理
- [x] **混合端口** - HTTP + SOCKS5 共用一个端口
- [x] Shadowsocks (AES-128-GCM, AES-256-GCM, ChaCha20-Poly1305)
- [x] VMess 协议
- [x] Trojan 协议
- [x] VLESS 出站连接（TCP 最小实现）

### 📋 规则引擎 (完整支持)

- [x] **DOMAIN** - 精确域名匹配
- [x] **DOMAIN-SUFFIX** - 域名后缀匹配 (Trie 树优化)
- [x] **DOMAIN-KEYWORD** - 域名关键词匹配
- [x] **IP-CIDR** - IPv4 CIDR 匹配
- [x] **IP-CIDR6** - IPv6 CIDR 匹配
- [x] **GEOIP** - 地理 IP 匹配
- [x] **SRC-IP-CIDR** - 源 IP CIDR 匹配
- [x] **DST-PORT** - 目标端口匹配 (支持范围)
- [x] **SRC-PORT** - 源端口匹配 (支持范围)
- [x] **PROCESS-NAME** - 进程名匹配
- [x] **FINAL (MATCH)** - 默认规则
- [x] **no-resolve** - 跳过 DNS 解析标记

### 🖥️ TUI 界面
- [x] **现代化界面** - 深色主题 + RGB 真彩色
- [x] **鼠标支持** - 点击、滚轮操作
- [x] **配置校验** - 启动时自动验证配置完整性
- [x] **节点延迟测试** - 一键测试所有节点延迟
- [x] **实时连接列表** - 查看活跃连接和流量统计
- [x] **配置重载** - TUI 内按 `r` 重载配置
- [x] 多标签页导航 (Groups / Proxies / Connections / Logs)

### 🔧 其他特性
- [x] YAML 配置解析
- [x] 代理组策略 (select / url-test / fallback / load-balance / relay)
- [x] REST API (端口 9090)
- [x] DNS 客户端 (UDP/TCP) + 缓存
- [x] WebSocket 传输
- [x] TLS 支持

---

## 功能状态

> 下面是当前仓库的实现状态，避免“配置可写但运行不可用”的误解。

| 协议 | 配置解析 | 配置校验 | 实际出站连接 |
|------|---------|---------|-------------|
| Shadowsocks | ✅ | ✅ | ✅ |
| VMess | ✅ | ✅ | ✅ |
| Trojan | ✅ | ✅ | ✅ |
| VLESS | ✅ | ✅ | ✅（TCP 最小实现） |

### VLESS 支持说明

当前已支持 `type: vless` 的基础 TCP 出站：
- 支持配置解析与校验（`server`、`port`、`uuid` 等）；
- 支持最小 VLESS 握手并建立 TCP 转发链路。

当前限制：
- 仅实现基础 TCP 流程；
- `tls` / `ws-opts` 等高级传输参数已可解析，但尚未在 VLESS 出站链路中完整启用。

---

## 快速开始

### 编译

需要 Zig 0.15.0+:

```bash
git clone https://github.com/yourusername/zclash
cd zclash
zig build
```

### CLI 使用

```bash
# 查看帮助
zclash help

# 启动 TUI（前台交互模式）
zclash tui

# 后台启动代理服务
zclash start
zclash start -c config.yaml

# 服务管理
zclash status    # 查看状态
zclash stop      # 停止服务
zclash restart   # 重启服务
zclash log       # 查看日志（默认 tail -f 50行）

# 配置管理
zclash config list                              # 列出所有配置
zclash config download <url> -n <name> -d       # 下载配置并设为默认
zclash config use <configname>                  # 切换配置
```

### 配置自动发现

zclash 会按以下顺序查找配置文件：

1. `~/.config/zclash/config.yaml`（通过 `zclash config use` 设置的当前配置）
2. `~/.zclash/config.yaml`
3. `./config.yaml`（当前目录）

如果都找不到，使用内置默认配置。

### 运行

```bash
# 使用默认配置启动 TUI
./zig-out/bin/zclash tui

# 指定配置文件启动 TUI
./zig-out/bin/zclash tui -c config.yaml

# 后台启动代理服务
./zig-out/bin/zclash start

# 指定配置后台启动
./zig-out/bin/zclash start -c config.yaml

# 查看帮助
./zig-out/bin/zclash help
```

### 测试代理

```bash
# 测试 HTTP 代理
curl -x http://127.0.0.1:7890 http://httpbin.org/ip

# 测试 SOCKS5 代理
curl -x socks5://127.0.0.1:7891 http://httpbin.org/ip

# 浏览器设置
# HTTP 代理: 127.0.0.1:7890
# SOCKS5 代理: 127.0.0.1:7891
```

---

## CLI 命令参考

### 基础命令

| 命令 | 说明 |
|------|------|
| `zclash help` | 显示帮助信息 |
| `zclash tui` | 启动 TUI 交互界面 |
| `zclash tui -c <path>` | 指定配置启动 TUI |

### 服务管理

| 命令 | 说明 |
|------|------|
| `zclash start` | 后台启动代理服务 |
| `zclash start -c <path>` | 指定配置启动 |
| `zclash stop` | 停止代理服务 |
| `zclash restart` | 重启代理服务 |
| `zclash restart -c <path>` | 指定配置重启 |
| `zclash status` | 查看服务状态 |
| `zclash log` | 查看日志（默认最后 50 行，持续刷新） |
| `zclash log -n 100` | 显示最后 100 行 |
| `zclash log --no-follow` | 显示后不持续刷新 |

### 配置管理

| 命令 | 说明 |
|------|------|
| `zclash config list` / `ls` | 列出所有已下载的配置 |
| `zclash config download <url>` | 从 URL 下载配置（使用域名作为文件名） |
| `zclash config download <url> -n <name>` | 下载并指定名称 |
| `zclash config download <url> -n <name> -d` | 下载并设为默认 |
| `zclash config use <configname>` | 切换到指定配置 |

### 代理管理

| 命令 | 说明 |
|------|------|
| `zclash proxy list` / `ls` | 列出所有代理组和节点 |
| `zclash proxy list -c <path>` | 指定配置列出代理 |
| `zclash proxy select` | 显示代理选择界面 |
| `zclash proxy select -g <group>` | 为指定组选择代理 |
| `zclash proxy select -g <group> -p <proxy>` | 选择指定组的指定代理 |

### 配置管理示例

```bash
# 下载订阅配置（默认使用域名作为文件名）
zclash config download https://example.com/subscribe.yaml
# 保存为: ~/.config/zclash/example.com.yaml

# 下载并指定自定义名称
zclash config download https://example.com/subscribe.yaml -n mysub

# 下载并设为默认（创建 config.yaml 符号链接）
zclash config download https://example.com/subscribe.yaml -n mysub -d

# 查看所有配置
zclash config list
# 输出：
#   example.com.yaml
#   mysub.yaml
# * mysub.yaml (active)

# 切换配置
zclash config use example.com.yaml
```

---

## TUI 界面

使用 `zclash tui` 命令启用交互式终端界面。

### 界面预览

```
 === zclash ===                     Proxy Dashboard
┌──────────┬──────────┬───────────────┬──────────┐
│ Groups   │ Proxies  │ Connections   │ Logs     │
└──────────┴──────────┴───────────────┴──────────┘

PROXY > Nodes (press 't' to test latency)

  Name              Type        Server              Latency
-------------------------------------------------------------
> 香港-01           Shadowsocks hk01.example.com:83   45ms
  香港-02           Shadowsocks hk02.example.com:83  120ms
  新加坡-01         Shadowsocks sg01.example.com:83   78ms
* DIRECT            Direct      -                     0ms

 Arrow/j,k:Navigate | Enter:Select | t:Test | r:Reload | q:Quit
```

### 快捷键

| 按键 | 功能 |
|------|------|
| `↑/↓` 或 `j/k` | 上下导航 |
| `←/→` 或 `h/l` | 切换标签页 |
| `Tab` | 下一个标签 |
| `Enter` / 空格 | 选择/确认 |
| `t` | **测试当前组节点延迟** |
| `r` | **重载配置文件** |
| `g` | 跳到顶部 |
| `G` | 跳到底部 |
| `q` | 退出 |

### 鼠标操作
- **点击标签页** - 切换视图
- **点击代理组/节点** - 选择
- **滚轮** - 滚动列表

### 标签页说明

#### 1. Groups - 代理组列表
显示所有代理组及其类型、节点数量。

#### 2. Proxies - 节点列表
- 显示节点名称、类型、服务器地址
- **延迟测试结果显示**：
  - 🟢 绿色 `< 100ms` - 优秀
  - 🟡 黄色 `100-300ms` - 良好
  - 🔴 红色 `> 300ms` - 较差
  - ⚫ 灰色 `--` - 未测试/超时

#### 3. Connections - 活跃连接
实时显示当前活跃的连接：
- 目标地址 (host:port)
- 使用的代理节点
- 上传/下载流量
- 连接持续时间

#### 4. Logs - 系统日志
显示代理运行日志和延迟测试结果。

---

## 配置说明

### 配置校验

启动时会自动验证配置，包含以下检查：
- ✅ 端口范围 (1-65535) 和冲突检测
- ✅ 代理节点必填字段验证
  - Shadowsocks: `password`, `cipher`
  - VMess: `uuid` (格式验证)
  - Trojan: `password`
  - DIRECT/REJECT: 无需 server/port
- ✅ 代理/代理组名称重复检查
- ✅ 代理组引用节点存在性检查
- ✅ 规则引用目标存在性检查
- ✅ IP CIDR 格式验证

配置错误时会输出详细错误列表并退出，**不会启动无效配置**。

### 最小配置示例

```yaml
port: 7890
socks-port: 7891

proxies:
  - name: DIRECT
    type: direct

proxy-groups:
  - name: Proxy
    type: select
    proxies:
      - DIRECT

rules:
  - MATCH,DIRECT
```

### VLESS 最小完整示例

> 用于快速验证 VLESS 配置解析与基础 TCP 出站是否可用。

```yaml
port: 7890
socks-port: 7891

proxies:
  - name: DIRECT
    type: direct

  - name: VLESS-DEMO
    type: vless
    server: vless.example.com
    port: 443
    uuid: 11111111-2222-3333-4444-555555555555
    tls: true
    sni: vless.example.com
    ws-opts:
      path: /ws
      headers:
        Host: vless.example.com

proxy-groups:
  - name: PROXY
    type: select
    proxies:
      - DIRECT
      - VLESS-DEMO

rules:
  - MATCH,DIRECT
```

### 完整配置示例

```yaml
# 监听端口
port: 7890              # HTTP 代理端口
socks-port: 7891        # SOCKS5 代理端口
mixed-port: 7892        # 混合端口 (设置后上面两个失效)

allow-lan: false
mode: rule
log-level: info

# REST API
external-controller: 127.0.0.1:9090

# 代理节点
proxies:
  - name: DIRECT
    type: direct

  - name: REJECT
    type: reject

  - name: SS-HK
    type: ss
    server: hk.example.com
    port: 8388
    cipher: aes-128-gcm
    password: "password"

  - name: VMess-US
    type: vmess
    server: us.example.com
    port: 443
    uuid: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    alterId: 0
    tls: true
    sni: us.example.com

  - name: Trojan-JP
    type: trojan
    server: jp.example.com
    port: 443
    password: "password"
    sni: jp.example.com

  # VLESS 示例（基础 TCP 出站可用）
  - name: VLESS-SG
    type: vless
    server: sg.example.com
    port: 443
    uuid: 11111111-2222-3333-4444-555555555555
    tls: true
    sni: sg.example.com
    ws-opts:
      path: /ws
      headers:
        Host: sg.example.com

# 代理组
proxy-groups:
  - name: PROXY
    type: select
    proxies:
      - SS-HK
      - VMess-US
      - Trojan-JP
      - VLESS-SG
      - DIRECT

  - name: Auto
    type: url-test
    url: http://www.gstatic.com/generate_204
    interval: 300
    proxies:
      - SS-HK
      - VMess-US
      - Trojan-JP

  - name: Fallback
    type: fallback
    url: http://www.gstatic.com/generate_204
    interval: 300
    proxies:
      - VMess-US
      - SS-HK
      - DIRECT

# 规则
rules:
  # 1. 精确域名匹配
  - DOMAIN,www.example.com,DIRECT
  
  # 2. 域名后缀匹配
  - DOMAIN-SUFFIX,google.com,PROXY
  - DOMAIN-SUFFIX,youtube.com,PROXY
  
  # 3. 域名关键词匹配
  - DOMAIN-KEYWORD,google,PROXY
  - DOMAIN-KEYWORD,ad,DIRECT
  
  # 4. IPv4 CIDR 匹配
  - IP-CIDR,192.168.0.0/16,DIRECT
  - IP-CIDR,10.0.0.0/8,DIRECT
  - IP-CIDR,172.16.0.0/12,DIRECT
  
  # 5. IPv6 CIDR 匹配
  - IP-CIDR6,fe80::/10,DIRECT
  - IP-CIDR6,2001:db8::/32,PROXY
  
  # 6. 地理 IP 匹配
  - GEOIP,CN,DIRECT
  - GEOIP,private,DIRECT
  
  # 7. 源 IP CIDR 匹配
  - SRC-IP-CIDR,192.168.1.0/24,DIRECT
  
  # 8. 目标端口匹配
  - DST-PORT,22,DIRECT
  - DST-PORT,80,PROXY
  - DST-PORT,443,PROXY
  - DST-PORT,8080-8090,PROXY
  
  # 9. 源端口匹配
  - SRC-PORT,12345,DIRECT
  
  # 10. 进程名匹配
  - PROCESS-NAME,ssh,DIRECT
  - PROCESS-NAME,curl,PROXY
  
  # 11. no-resolve 标记 (跳过 DNS 解析)
  - DOMAIN-SUFFIX,local,DIRECT,no-resolve
  - DOMAIN-SUFFIX,lan,DIRECT,no-resolve
  
  # 12. 默认规则
  - MATCH,PROXY
```

### 规则优先级

规则按顺序匹配，匹配成功即停止。建议顺序：

1. **PROCESS-NAME** - 进程名 (最优先)
2. **SRC-IP-CIDR** - 源 IP
3. **SRC-PORT** - 源端口
4. **DST-PORT** - 目标端口
5. **DOMAIN / DOMAIN-SUFFIX / DOMAIN-KEYWORD** - 域名
6. **GEOIP / IP-CIDR / IP-CIDR6** - IP 相关
7. **MATCH** - 默认规则 (最后)

### 特殊标记

- **no-resolve** - 跳过 DNS 解析，用于避免泄漏
  ```yaml
  - DOMAIN-SUFFIX,local,DIRECT,no-resolve
  ```

| 类型 | 必需字段 | 可选字段 |
|------|---------|---------|
| `direct` | `name`, `type` | - |
| `reject` | `name`, `type` | - |
| `ss` | `server`, `port`, `password`, `cipher` | - |
| `vmess` | `server`, `port`, `uuid` | `alterId`, `tls`, `sni`, `ws` |
| `trojan` | `server`, `port`, `password` | `tls`, `sni` |
| `vless` | `server`, `port`, `uuid` | `tls`, `sni`, `ws-opts`（当前仅解析） |

### Shadowsocks 加密方式

- `aes-128-gcm`
- `aes-192-gcm`
- `aes-256-gcm`
- `aes-128-cfb`
- `aes-192-cfb`
- `aes-256-cfb`
- `chacha20-ietf-poly1305`
- `chacha20-poly1305`
- `rc4-md5`
- `none`

---

## 项目结构

```
zclash/
├── src/
│   ├── main.zig              # 程序入口
│   ├── config.zig            # 配置解析
│   ├── config_validator.zig  # 配置校验
│   ├── daemon.zig            # 守护进程管理
│   ├── tui.zig               # TUI 界面
│   ├── dns/                  # DNS 客户端
│   │   ├── client.zig
│   │   └── protocol.zig
│   ├── protocol/             # 代理协议实现
│   │   ├── vmess.zig
│   │   └── trojan.zig
│   ├── proxy/
│   │   ├── http.zig          # HTTP 代理
│   │   ├── socks5.zig        # SOCKS5 代理
│   │   ├── mixed.zig         # 混合端口
│   │   └── outbound/         # 出站管理
│   │       ├── manager.zig
│   │       └── shadowsocks.zig
│   ├── rule/
│   │   └── engine.zig        # 规则引擎
│   └── api/
│       └── server.zig        # REST API
├── config.yaml               # 示例配置
├── config_test.yaml          # 测试配置
├── P0_FEATURES.md            # P0 功能文档
├── build.zig
└── README.md
```

---

## 开发

### 运行测试

```bash
zig build test
```

### 最小 Smoke Test

```bash
# 1) 构建
zig build

# 2) 测试配置管理
./zig-out/bin/zclash config list
./zig-out/bin/zclash config download https://example.com/config.yaml -n test -d

# 3) 启动 TUI（前台测试）
./zig-out/bin/zclash tui

# 或后台启动
./zig-out/bin/zclash start
./zig-out/bin/zclash status
./zig-out/bin/zclash log

# 4) 另开终端验证本地代理端口（示例：HTTP 7890）
curl -x http://127.0.0.1:7890 http://httpbin.org/ip

# 5) 停止服务
./zig-out/bin/zclash stop
```

### 调试模式

```bash
zig build -Doptimize=Debug
```

### 清理构建

```bash
rm -rf .zig-cache zig-out
zig build
```

---

## 性能

- **零开销抽象** - Zig 编译器优化
- **无 GC** - 手动内存管理，无停顿
- **内存安全** - 编译期边界检查
- **异步 I/O** - 基于事件循环的高并发

---

## 许可证

MIT License

---

<p align="center">
  Made with ❤️ using Zig
</p>

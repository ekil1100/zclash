# zclash

用 Zig 语言实现的高性能代理工具，兼容 Clash 配置格式。

## 功能特性

### 代理协议
- [x] HTTP/HTTPS 代理 (CONNECT + 普通 HTTP)
- [x] SOCKS5 代理
- [x] Shadowsocks (AES-128-GCM, AES-256-GCM, ChaCha20-Poly1305)
- [x] VMess 协议
- [x] Trojan 协议
- [x] 混合端口 (HTTP + SOCKS5 共用一个端口)

### 规则引擎
- [x] DOMAIN - 精确域名匹配
- [x] DOMAIN-SUFFIX - 域名后缀匹配
- [x] DOMAIN-KEYWORD - 域名关键词匹配
- [x] IP-CIDR - IP 段匹配
- [x] GEOIP - 地理 IP 匹配
- [x] FINAL (MATCH) - 默认规则

### DNS
- [x] DNS 客户端 (UDP/TCP)
- [x] DNS 缓存
- [x] 规则匹配时自动解析域名

### 其他
- [x] YAML 配置解析
- [x] 规则组 (select, url-test, fallback, load-balance)
- [x] REST API (端口 9090)
- [x] WebSocket 传输
- [x] TLS 支持
- [ ] 完整 TLS 握手实现

## 测试

```bash
# 运行所有测试
zig build test
```

当前有 **17 个测试文件**，涵盖主要功能模块。

## 编译

需要 Zig 0.15.0+:

```bash
zig build
```

## 运行

```bash
# 使用默认配置
./zig-out/bin/zclash

# 指定配置文件
./zig-out/bin/zclash -c /path/to/config.yaml

# 启用 TUI 界面
./zig-out/bin/zclash --tui

# 查看帮助
./zig-out/bin/zclash -h
```

## TUI 界面

使用 `--tui` 参数启用交互式终端界面：

- **j/k** 或 **↑/↓**: 导航代理列表
- **Enter**: 选择代理  
- **q**: 退出

显示信息：
- 当前使用的代理
- 上传/下载速度
- 活跃连接数
- 可用代理列表
- 日志输出

## 配置示例

```yaml
# 监听端口
port: 7890              # HTTP 代理端口
socks-port: 7891        # SOCKS5 代理端口
mixed-port: 7892        # 混合端口 (HTTP + SOCKS5)，设置后上面两个失效

allow-lan: false
mode: rule
log-level: info

# 代理节点
proxies:
  - name: "DIRECT"
    type: direct

  - name: "Shadowsocks"
    type: ss
    server: 1.2.3.4
    port: 8388
    cipher: aes-128-gcm
    password: "your-password"

  - name: "VMess"
    type: vmess
    server: vmess.example.com
    port: 443
    uuid: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    alterId: 0

  - name: "Trojan"
    type: trojan
    server: trojan.example.com
    port: 443
    password: "your-password"
    sni: trojan.example.com

# 代理组
proxy-groups:
  - name: Proxy
    type: select
    proxies:
      - DIRECT
      - Shadowsocks
      - VMess
      - Trojan

# 规则
rules:
  - DOMAIN-SUFFIX,google.com,Proxy
  - DOMAIN-KEYWORD,google,Proxy
  - GEOIP,CN,DIRECT
  - MATCH,DIRECT
```

## 项目结构

```
zclash/
├── src/
│   ├── main.zig              # 入口
│   ├── config.zig            # 配置解析
│   ├── dns/                  # DNS 客户端
│   │   ├── client.zig
│   │   └── protocol.zig
│   ├── protocol/             # 代理协议
│   │   ├── vmess.zig
│   │   └── trojan.zig
│   ├── proxy/
│   │   ├── http.zig          # HTTP 代理
│   │   ├── socks5.zig        # SOCKS5 代理
│   │   ├── mixed.zig         # 混合端口
│   │   └── outbound/         # 出站管理
│   │       ├── manager.zig
│   │       └── shadowsocks.zig
│   └── rule/
│       └── engine.zig        # 规则引擎
├── config.yaml               # 示例配置
├── build.zig
└── README.md
```

## 测试

```bash
# 运行单元测试
zig build test

# 启动代理测试
./zig-out/bin/zclash -c config.yaml

# 测试 HTTP 代理
curl -x http://127.0.0.1:7890 http://httpbin.org/ip

# 测试 SOCKS5 代理
curl -x socks5://127.0.0.1:7891 http://httpbin.org/ip
```

## 性能

Zig 语言实现，无 GC，内存安全，性能优异。

## 许可证

MIT

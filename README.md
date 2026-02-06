# clash-zig

用 Zig 语言实现的 Clash 核心代理工具。

## 功能

- [x] HTTP 代理 (CONNECT + 普通 HTTP)
- [x] SOCKS5 代理
- [x] 规则引擎 (DOMAIN, DOMAIN-SUFFIX, DOMAIN-KEYWORD, IP-CIDR, FINAL)
- [x] 配置解析
- [ ] Shadowsocks 协议
- [ ] VMess 协议
- [ ] Trojan 协议
- [ ] REST API
- [ ] DNS 解析
- [ ] 规则组 (url-test, fallback, load-balance)

## 编译

需要 Zig 0.13.0+:

```bash
zig build
```

## 运行

```bash
# 使用默认配置
./zig-out/bin/clash-zig

# 指定配置文件
./zig-out/bin/clash-zig -c /path/to/config.yaml
```

## 默认端口

- HTTP 代理: `7890`
- SOCKS5 代理: `7891`

## 配置示例

```yaml
port: 7890
socks-port: 7891
allow-lan: false
mode: rule
log-level: info

proxies:
  - name: "PROXY"
    type: http
    server: 127.0.0.1
    port: 8080

rules:
  - DOMAIN-SUFFIX,google.com,PROXY
  - DOMAIN-KEYWORD,google,PROXY
  - GEOIP,CN,DIRECT
  - MATCH,DIRECT
```

## 架构

```
clash-zig/
├── src/
│   ├── main.zig          # 入口
│   ├── config.zig        # 配置解析
│   ├── proxy/
│   │   ├── http.zig      # HTTP 代理
│   │   ├── socks5.zig    # SOCKS5 代理
│   │   └── ...
│   └── rule/
│       └── engine.zig    # 规则引擎
└── build.zig
```

## 许可证

MIT

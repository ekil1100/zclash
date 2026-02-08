# zclash P0 功能完成清单

## ✅ 1. 配置校验 (Config Validation)

启动时自动验证配置，错误会阻止程序启动。

### 校验内容：
- 端口范围 (1-65535) 和冲突检查
- 代理节点必填字段验证
  - Shadowsocks: password, cipher
  - VMess: uuid (格式验证)
  - Trojan: password
  - DIRECT/REJECT: 不需要 server/port
- 代理组引用的节点是否存在
- 规则引用的目标是否存在 (DIRECT/REJECT 除外)
- IP CIDR 格式验证
- 重复名称检查
- 循环引用检查

### 使用：
```bash
./zclash -c config.yaml
# 配置错误时会输出错误列表并退出
```

---

## ✅ 2. 节点延迟测试 (Latency Test)

TUI 界面中按 `t` 测试当前代理组所有节点延迟。

### 功能：
- 按 `t` 启动测试
- 异步测试，不阻塞界面
- 延迟分级显示：
  - 🟢 < 100ms (绿色)
  - 🟡 100-300ms (黄色)
  - 🔴 > 300ms (红色)
  - ⚫ timeout (失败)

### 使用：
```bash
./zclash -c config.yaml --tui
# 进入 Proxies 标签页
# 按 't' 测试延迟
```

---

## ✅ 3. 配置热重载 (Config Reload)

TUI 界面中按 `r` 触发重载请求。

### 功能：
- 按 `r` 发送重载请求
- 日志显示重载状态
- 实际重载需要重启程序（受限于架构）

### 使用：
```bash
./zclash -c config.yaml --tui
# 修改配置文件后
# 按 'r' 触发重载
```

---

## ✅ 4. 实时连接列表 (Active Connections)

TUI 新增 Connections 标签页，显示当前活跃连接。

### 显示信息：
- 连接 ID
- 目标地址 (host:port)
- 使用的代理节点
- 上传/下载流量
- 连接持续时间

### 使用：
```bash
./zclash -c config.yaml --tui
# 按 Tab 或方向键切换到 Connections 标签
```

---

## TUI 操作指南

### 快捷键：
| 按键 | 功能 |
|------|------|
| `↑/↓` 或 `j/k` | 导航 |
| `←/→` 或 `h/l` | 切换标签页 |
| `Tab` | 下一个标签 |
| `Enter` | 选择/确认 |
| `t` | 测试延迟 |
| `r` | 重载配置 |
| `g` | 跳到顶部 |
| `G` | 跳到底部 |
| `q` | 退出 |

### 标签页：
1. **Groups** - 代理组列表
2. **Proxies** - 节点列表（支持延迟显示）
3. **Connections** - 活跃连接
4. **Logs** - 系统日志

### 鼠标支持：
- 点击标签页切换
- 点击选择代理组/节点
- 滚轮滚动列表

---

## 测试配置

使用 `config_test.yaml` 测试所有功能：

```bash
# 验证配置
./zclash -c config_test.yaml

# 启动 TUI
./zclash -c config_test.yaml --tui
```

测试配置包含：
- 8 个代理节点 (DIRECT, REJECT, 6 个 SS/VMess)
- 3 个代理组 (select, url-test, fallback)
- 8 条规则

# API Error Codes（P2-2 初稿）

## 1) 目标

为 zclash API 提供稳定、可机器识别、可人类操作的错误码体系。

统一错误响应信封：

```json
{
  "ok": false,
  "error": {
    "code": "CONFIG_NOT_FOUND",
    "message": "config file not found",
    "hint": "run `zclash profile list` and choose a valid profile"
  }
}
```

---

## 2) 命名规则

- 全大写 + 下划线：`DOMAIN_DETAIL_REASON`
- 建议结构：`<LAYER>_<ACTION>_<DETAIL>`
- 避免把动态信息写进 `code`（动态信息放 `message`）
- 同类语义错误只保留一个主 code，避免重复

示例：
- `CONFIG_NOT_FOUND`
- `NETWORK_DNS_FAILED`
- `PROVIDER_UNREACHABLE`
- `VALIDATION_RULE_INVALID`
- `AUTH_PERMISSION_DENIED`

---

## 3) 分层体系（至少 5 类）

## A. 配置类（CONFIG_*)

| code | message 示例 | hint 示例 |
|---|---|---|
| `CONFIG_NOT_FOUND` | config file not found | run `zclash profile list` and select a valid profile |
| `CONFIG_PARSE_FAILED` | failed to parse config yaml | check yaml syntax and run `zclash profile validate <file>` |
| `CONFIG_SWITCH_FAILED` | failed to switch active config | verify file permission and retry |

## B. 网络类（NETWORK_*)

| code | message 示例 | hint 示例 |
|---|---|---|
| `NETWORK_DNS_FAILED` | dns resolve failed for target | verify dns setting and upstream availability |
| `NETWORK_CONNECT_TIMEOUT` | tcp connect timeout | check proxy node health and network route |
| `NETWORK_PORT_IN_USE` | required local port is already in use | free the port or change config port |

## C. 提供商/上游类（PROVIDER_*)

| code | message 示例 | hint 示例 |
|---|---|---|
| `PROVIDER_UNREACHABLE` | upstream provider is unreachable | check provider endpoint/network/proxy chain |
| `PROVIDER_AUTH_FAILED` | provider authentication failed | verify token/credential and retry |
| `PROVIDER_RESPONSE_INVALID` | provider response format invalid | check provider compatibility and version |

## D. 校验类（VALIDATION_*)

| code | message 示例 | hint 示例 |
|---|---|---|
| `VALIDATION_RULE_INVALID` | rule format is invalid | use supported rule format and rerun validate |
| `VALIDATION_PROXY_INVALID` | proxy definition is invalid | check required proxy fields |
| `VALIDATION_PORT_CONFLICT` | config has port conflict | adjust mixed/http/socks port settings |

## E. 权限类（AUTH_*)

| code | message 示例 | hint 示例 |
|---|---|---|
| `AUTH_PERMISSION_DENIED` | permission denied for requested action | check role/token scope |
| `AUTH_TOKEN_MISSING` | auth token is missing | provide valid token in request |
| `AUTH_TOKEN_INVALID` | auth token is invalid | refresh token and retry |

---

## 4) 设计原则

1. `code` 稳定：供前端/脚本分支判断。
2. `message` 可读：一句话说清发生了什么。
3. `hint` 可执行：给用户下一步动作。
4. 尽量避免返回裸异常名（例如 `FileNotFound`）给最终用户。

---

## 5) 后续落地

1. 在 OpenAPI 中引用统一 `ErrorResponse`。
2. CLI/API 逐步替换零散错误文本为标准错误码。
3. 为高频 code 增加集成测试断言（至少覆盖 profile/proxy/diag 路径）。

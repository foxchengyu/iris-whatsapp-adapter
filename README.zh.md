# iris-whatsapp-adapter

[![English](https://img.shields.io/badge/README-English-blue)](./README.md)

用于 **WhatsApp Cloud API**（Meta）的 InterSystems IRIS 互操作性适配器。直接从 IRIS 生产环境收发 WhatsApp 消息——不需要 Python、Node.js 或任何外部服务。

> 为 InterSystems 社区悬赏计划"想法到应用"第 3 轮构建 — 想法 **DPI-I-882**。

## 功能

- **发送文本消息** — 从任意 IRIS 生产环境调用 WhatsApp Cloud API
- **发送模板消息** — 支持 header/body/button 参数
- **发送交互式消息** — 列表选择器、回复按钮、CTA URL
- **接收消息** — Meta webhook 自动解析并路由到生产环境
- **标记已读** — 让 WhatsApp 显示绿色勾
- **下载媒体** — 通过 media ID 下载图片、音频、文档
- **零外部依赖** — 纯 ObjectScript 互操作性适配器
- **自动 TLS 配置** — 即使 IRIS 镜像没有 SSL 配置也能开箱即用
- **代理支持** — 适用于受限网络环境
- **Docker 一键启动**

## 快速开始

### 1. 获取 WhatsApp Cloud API 凭证

1. 前往 [Meta for Developers](https://developers.facebook.com/) 创建一个商务应用
2. 为应用添加 **WhatsApp** 产品
3. 在 **WhatsApp → API Setup** 中，记录：
   - **Phone Number ID**
   - **临时访问令牌**（或生成长期令牌）
4. 设置 **Webhook**（可稍后配置——适配器的发送功能立即可用）

### 2. 配置

```bash
cp .env.example .env
```

编辑 `.env`：

```env
WA_ACCESS_TOKEN=你的访问令牌
WA_PHONE_NUMBER_ID=你的手机号ID
WA_VERIFY_TOKEN=任意随机字符串
```

### 3. 启动容器

```bash
docker compose up -d --build
```

搞定。生产环境自动启动并预配置适配器。

### 4. 发送测试消息

打开 IRIS 管理门户（`http://localhost:52773/csp/sys/UtilHome.csp`），切换到 **USER** 命名空间，执行：

```objectscript
Set tReq = ##class(IrisWhatsApp.Msg.TextRequest).%New()
Set tReq.To = "8613800138000"
Set tReq.Body = "Hello from InterSystems IRIS!"

Set tOp = ##class(Ens.Director).CreateBusinessOperation("WhatsAppOut", .tSC)
Set tSC = tOp.SendRequestAsync("IrisWhatsApp.Out.Operation", tReq)
Write "Sent! Status: ", $System.Status.GetErrorText(tSC)
```

或通过 SQL 发送：

```sql
SELECT IrisWhatsApp.Out_Operation_SendText('8613800138000', 'Hello from IRIS SQL!')
```

### 5. 配置 Webhook（接收消息）

1. 将 IRIS 实例暴露到公网（隧道、ngrok 或公网 IP）
2. 在 Meta App → WhatsApp → Configuration 中：
   - **Callback URL**：`https://你的服务器/csp/whatsapp/IrisWhatsApp.Webhook.cls/whatsapp`
   - **Verify token**：与 `.env` 中 `WA_VERIFY_TOKEN` 相同的值
3. 订阅 **messages** webhook 字段

收到的消息会自动传送到 `IrisWhatsApp.In.Service`，配置路由规则即可处理。

## 架构

```
┌─────────────────────────────────────────────────────┐
│                   IRIS 生产环境                      │
│                                                     │
│  ┌──────────────────────┐   ┌───────────────────┐  │
│  │ In.Service           │   │ WhatsAppOut       │  │
│  │ (Ens.InboundAdapter) │   │ (Ens.BusinessOp)  │  │
│  │                      │   │                   │  │
│  │ ProcessInput()       │   │ SendText()        │  │
│  │ 处理入站消息          │   │ SendTemplate()    │  │
│  │ WebhookRequest       │   │ MarkAsRead()      │  │
│  └──────────▲───────────┘   └────────┬──────────┘  │
│             │                        │              │
│  ┌──────────┴───────────┐   ┌────────┴──────────┐  │
│  │ IrisWhatsApp.Webhook │   │ Out.Adapter       │  │
│  │ (CSP REST 处理器)     │   │ (HTTP → Meta API) │  │
│  │                      │   │                   │  │
│  │ GET  /whatsapp       │   │ TLS 自动创建      │  │
│  │ POST /whatsapp       │   │ 代理支持          │  │
│  └──────────▲───────────┘   └────────┬──────────┘  │
│             │                        │              │
└─────────────┼────────────────────────┼──────────────┘
              │                        │
     ┌────────┴────────┐      ┌────────┴────────┐
     │  Meta Webhook   │      │  Meta Graph API │
     │  (接收消息)      │      │  (发送消息)      │
     └─────────────────┘      └─────────────────┘
```

## 类参考

| 类 | 作用 |
|-------|------|
| `IrisWhatsApp.Out.Adapter` | HTTP 适配器 — 处理认证、TLS、代理、JSON 负载 |
| `IrisWhatsApp.Out.Operation` | 业务操作 — `SendText`、`SendTemplate`、`SendInteractive`、`MarkAsRead` |
| `IrisWhatsApp.In.Service` | 业务服务 — 接收解析后的 webhook 消息 |
| `IrisWhatsApp.Webhook` | CSP REST 处理器 — webhook 验证 + 消息转发 |
| `IrisWhatsApp.Msg.TextRequest` | `Ens.Request` — 发送文本消息 |
| `IrisWhatsApp.Msg.SendResponse` | `Ens.Response` — 包含消息 ID 和状态 |
| `IrisWhatsApp.Msg.WebhookRequest` | `Ens.Request` — 携带入站 WhatsApp 消息 |
| `IrisWhatsApp.TLS` | 自动创建 SSL/TLS 客户端配置 |
| `IrisWhatsApp.Utils` | 静态工具：流读取、时间戳、异常处理 |
| `IrisWhatsApp.Setup` | 首次启动时创建 CSP 应用和示例生产环境 |

## 配置参考

所有设置可在管理门户的 `Settings` → `IrisWhatsApp.Out.Adapter` 中修改，或通过环境变量配置：

| 设置项 | 环境变量 | 必填 | 默认值 |
|---------|-------------|----------|---------|
| AccessToken | `WA_ACCESS_TOKEN` | 是 | — |
| PhoneNumberID | `WA_PHONE_NUMBER_ID` | 是 | — |
| ApiVersion | — | 否 | `v22.0` |
| SSLConfiguration | — | 否 | 自动创建 |
| ProxyServer | `WA_PROXY` | 否 | — |

Webhook 验证令牌通过 `WA_VERIFY_TOKEN` 设置。

## Webhook URL

| 方法 | 端点 | 用途 |
|--------|----------|---------|
| GET | `/csp/whatsapp/IrisWhatsApp.Webhook.cls/whatsapp` | Meta 验证握手 |
| POST | `/csp/whatsapp/IrisWhatsApp.Webhook.cls/whatsapp` | 接收消息 |
| GET | `/csp/whatsapp/IrisWhatsApp.Webhook.cls/test` | 健康检查 |

## 系统要求

- InterSystems IRIS 2023.1+（社区版即可）
- Docker（容器化部署）
- Meta 商务应用（含 WhatsApp 产品）
- WhatsApp Business 电话号码（测试号码即可）

## 许可证

MIT © 2026 foxchengyu
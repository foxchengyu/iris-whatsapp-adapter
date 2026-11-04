# iris-whatsapp-adapter

[![中文版](https://img.shields.io/badge/README-中文版-red)](./README.zh.md)

InterSystems IRIS Interoperability adapter for the **WhatsApp Cloud API** (Meta). Send and receive WhatsApp messages directly from your IRIS production — no Python, no Node.js, no external service required.

> Built for the InterSystems Community Bounty "Idea to Application" Round 3 — Idea **DPI-I-882**.

## Features

- **Send text messages** via the WhatsApp Cloud API from any IRIS production
- **Send template messages** with header/body/button parameters
- **Send interactive messages** (list pickers, reply buttons, CTA URLs)
- **Receive incoming messages** via Meta webhook — parsed and routed into your production
- **Mark messages as read** for green checkmarks in WhatsApp
- **Download media** (images, audio, documents) by media ID
- **Zero external dependencies** — pure ObjectScript Interoperability adapter
- **Auto TLS configuration** — works out of the box even on IRIS images without SSL config
- **Proxy support** for restricted networks
- **Docker-based** — one command to start

## Quick Start

### 1. Get WhatsApp Cloud API Credentials

1. Go to [Meta for Developers](https://developers.facebook.com/) and create a Business App
2. Add the **WhatsApp** product to your app
3. In **WhatsApp → API Setup**, note your:
   - **Phone Number ID**
   - **Temporary Access Token** (or generate a permanent one)
4. Set up a **Webhook** (you can do this later — the adapter works for outbound immediately)

### 2. Configure

```bash
cp .env.example .env
```

Edit `.env`:

```env
WA_ACCESS_TOKEN=your_access_token_here
WA_PHONE_NUMBER_ID=your_phone_number_id_here
WA_VERIFY_TOKEN=any_random_string_you_choose
```

### 3. Start the Container

```bash
docker compose up -d --build
```

That's it. The production autostarts and pre-configures the adapter.

### 4. Send a Test Message

Open the IRIS Management Portal (`http://localhost:52773/csp/sys/UtilHome.csp`), switch to the **USER** namespace, and run:

```objectscript
Set tReq = ##class(IrisWhatsApp.Msg.TextRequest).%New()
Set tReq.To = "8613800138000"
Set tReq.Body = "Hello from InterSystems IRIS!"

Set tOp = ##class(Ens.Director).CreateBusinessOperation("WhatsAppOut", .tSC)
Set tSC = tOp.SendRequestAsync("IrisWhatsApp.Out.Operation", tReq)
Write "Sent! Status: ", $System.Status.GetErrorText(tSC)
```

Or send via SQL:

```sql
SELECT IrisWhatsApp.Out_Operation_SendText('8613800138000', 'Hello from IRIS SQL!')
```

### 5. Set Up the Webhook (for Inbound)

1. Expose your IRIS instance to the internet (tunnel, ngrok, or public IP)
2. In your Meta App → WhatsApp → Configuration:
   - **Callback URL**: `https://your-server/csp/whatsapp/IrisWhatsApp.Webhook.cls/whatsapp`
   - **Verify token**: same value as `WA_VERIFY_TOKEN` in your `.env`
3. Subscribe to the **messages** webhook field

Incoming messages are now delivered to `IrisWhatsApp.In.Service` in your production. Configure a routing rule to process them.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   IRIS Production                   │
│                                                     │
│  ┌──────────────────────┐   ┌───────────────────┐  │
│  │ In.Service           │   │ WhatsAppOut       │  │
│  │ (Ens.InboundAdapter) │   │ (Ens.BusinessOp)  │  │
│  │                      │   │                   │  │
│  │ ProcessInput()       │   │ SendText()        │  │
│  │ processes inbound    │   │ SendTemplate()    │  │
│  │ WebhookRequest       │   │ MarkAsRead()      │  │
│  └──────────▲───────────┘   └────────┬──────────┘  │
│             │                        │              │
│  ┌──────────┴───────────┐   ┌────────┴──────────┐  │
│  │ IrisWhatsApp.Webhook │   │ Out.Adapter       │  │
│  │ (CSP REST handler)   │   │ (HTTP → Meta API) │  │
│  │                      │   │                   │  │
│  │ GET  /whatsapp       │   │ TLS auto-create   │  │
│  │ POST /whatsapp       │   │ Proxy support     │  │
│  └──────────▲───────────┘   └────────┬──────────┘  │
│             │                        │              │
└─────────────┼────────────────────────┼──────────────┘
              │                        │
     ┌────────┴────────┐      ┌────────┴────────┐
     │  Meta Webhook   │      │  Meta Graph API │
     │  (incoming msgs)│      │  (send msgs)     │
     └─────────────────┘      └─────────────────┘
```

## Class Reference

| Class | Role |
|-------|------|
| `IrisWhatsApp.Out.Adapter` | HTTP adapter for Meta Cloud API — handles auth, TLS, proxy, JSON payloads |
| `IrisWhatsApp.Out.Operation` | Business Operation — `SendText`, `SendTemplate`, `SendInteractive`, `MarkAsRead` |
| `IrisWhatsApp.In.Service` | Business Service — receives parsed webhook messages |
| `IrisWhatsApp.Webhook` | CSP REST handler — webhook verification + message forwarding |
| `IrisWhatsApp.Msg.TextRequest` | `Ens.Request` for sending text messages |
| `IrisWhatsApp.Msg.SendResponse` | `Ens.Response` with message ID and status |
| `IrisWhatsApp.Msg.WebhookRequest` | `Ens.Request` carrying an inbound WhatsApp message |
| `IrisWhatsApp.TLS` | Auto-creates an SSL/TLS client configuration when missing |
| `IrisWhatsApp.Utils` | Static helpers: stream reading, timestamps, exceptions |
| `IrisWhatsApp.Setup` | Creates the CSP app and sample production on first boot |

## Configuration Reference

All settings are in `Settings` → `IrisWhatsApp.Out.Adapter` in the Management Portal, or via environment variables:

| Setting | Env Variable | Required | Default |
|---------|-------------|----------|---------|
| AccessToken | `WA_ACCESS_TOKEN` | Yes | — |
| PhoneNumberID | `WA_PHONE_NUMBER_ID` | Yes | — |
| ApiVersion | — | No | `v22.0` |
| SSLConfiguration | — | No | auto-created |
| ProxyServer | `WA_PROXY` | No | — |

The verify token for webhooks is set via `WA_VERIFY_TOKEN`.

## Webhook URL

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/csp/whatsapp/IrisWhatsApp.Webhook.cls/whatsapp` | Meta verification handshake |
| POST | `/csp/whatsapp/IrisWhatsApp.Webhook.cls/whatsapp` | Incoming message delivery |
| GET | `/csp/whatsapp/IrisWhatsApp.Webhook.cls/test` | Health check |

## Requirements

- InterSystems IRIS 2023.1+ (Community Edition works)
- Docker (for the containerised setup)
- A Meta Business App with WhatsApp product
- A WhatsApp Business phone number (test number is fine)

## License

MIT © 2026 foxchengyu
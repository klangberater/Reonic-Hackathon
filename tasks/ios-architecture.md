# iOS Demo Architecture

**Client:** native iOS (SwiftUI), demoed on a **real iPhone**.
**Backend:** Node/TS deployed to the team's own server (public HTTPS). Hosts the MCP server.
**Decisions (2026-06-20):** real phone → deployed backend; backend hosts the MCP server.

```
iPhone (SwiftUI) ──HTTPS──► server (Node/TS)
                              ├─ REST/SSE endpoints for the app
                              └─ Claude tool-loop ⇄ MCP server (7 tools) ──► data/
```

Real phone + deployed backend = phone only needs internet (even cellular); no venue-Wi-Fi
peer-isolation risk. Base URL stays configurable so we can also point at localhost/Simulator.

## Repo layout (to scaffold)
```
mcp-server/   TS MCP server: the 7 tools (mcp-tools-design.md) over ../data/
backend/      TS service: Claude Agent SDK (connects to mcp-server) + Fastify REST/SSE
              endpoints; Dockerfile; .env.example (ANTHROPIC_API_KEY, DEMO_CLOCK)
ios/          SwiftUI app: NowScreen, ChatView, APIClient, Codable models, base-URL config,
              summer/winter demo toggle
```

## App ↔ backend contract (mirrors tool outputs)
- `GET /state?household=HH-1001&clock=summer` → get_current_state shape (the glance).
- `GET /insights?household=HH-1001&clock=summer` → date-aware proactive nudges.
- `GET /prices?household=HH-1001&start&end` → forward price strip.
- `POST /chat {household, clock, message, history}` → grounded answer (later: SSE stream of
  tokens + which tools were called, for a "watch it reason" effect).
iOS `Codable` structs are generated to match these 1:1.

## Things to get right
- **iOS App Transport Security (ATS):** iOS requires **HTTPS** by default. If the server has a
  TLS domain → nothing to do. If it's plain `http://IP:port`, add an `NSAppTransportSecurity`
  exception in Info.plist (fine for a demo) — but HTTPS is strongly preferred.
- **Anthropic key** lives only on the backend (never in the app).
- **Demo clock**: `summer` = 2026-06-20T13:00, `winter` = a mid-Jan day. One switch flips /state,
  /insights, and the chat's "now" so the winter anomaly story is one tap away.
- **MCP wiring**: backend uses the Claude Agent SDK (TS) with our MCP server. Consult the
  `claude-api` skill for exact MCP + tool-loop wiring at build time.

## Build order
1. `mcp-server/` tools 1,3,5 over data/ (glance + decision + money tool), test standalone.
2. `backend/` Claude tool-loop + `/state` `/chat`; deploy a hello-world to the server early to
   de-risk deploy + HTTPS + ATS.
3. `ios/` NowScreen against `/state`, then ChatView against `/chat`.
4. Remaining tools (2,4,6,7) + summer insight set + winter toggle + polish.
```
```

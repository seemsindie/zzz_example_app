# zzz Example App

A comprehensive demo application showcasing the features of the zzz web framework. Serves as both a reference implementation and a learning resource.

## Running

```bash
cd example_app
zig build run
# Server running on http://127.0.0.1:9000
```

### With PostgreSQL

```bash
docker compose up -d          # Start PostgreSQL + Adminer
zig build run -Dpostgres=true
```

### With TLS

```bash
zig build run -Dtls=true
# HTTPS on https://127.0.0.1:9000 (dev certificates included)
```

## What's Demonstrated

### Core Web

| Route | Feature |
|-------|---------|
| `GET /` | Home page with template rendering |
| `GET /about` | Static page with layout system |
| `GET /api/status` | JSON health check |
| `GET /api/docs` | Swagger UI (auto-generated OpenAPI spec) |
| `GET /download/:filename` | File downloads via `sendFile` |
| `GET /error-demo` | Global error handler |

### REST API

| Route | Feature |
|-------|---------|
| `GET /api/users` | List users (JSON) |
| `GET /api/users/:id` | Get user by ID |
| `POST /api/users` | Create user |
| `POST /api/echo` | Echo body (JSON, form, multipart, text) |
| `POST /api/upload` | Multipart file upload |
| `CRUD /api/posts/:slug` | RESTful resource |

### Authentication

| Route | Feature |
|-------|---------|
| `GET /auth/bearer` | Bearer token auth |
| `GET /auth/basic` | Basic auth (username:password) |
| `GET /auth/jwt` | JWT/HS256 auth |
| `GET /api/limited` | Rate limiting (10 req/min) |

### Sessions & Cookies

| Route | Feature |
|-------|---------|
| `GET /login` | Login page with CSRF token |
| `GET /dashboard` | Session data display |
| `POST /api/protected` | CSRF-protected endpoint |
| `GET /set-cookie` | Set cookie |
| `GET /delete-cookie` | Delete cookie |
| `GET /old-page` | 301 redirect |

### htmx

| Route | Feature |
|-------|---------|
| `GET /htmx` | Interactive counter |
| `POST /htmx/increment` | HTMX partial update |
| `GET /todos` | Full CRUD todo list |

### WebSocket & Channels

| Route | Feature |
|-------|---------|
| `GET /ws-demo` | WebSocket echo demo |
| `WS /ws/echo` | WebSocket echo server |
| `GET /chat` | Channel-based chat |
| `CHANNEL /socket` | Phoenix-style channels (`room:*`) |

### Database

| Route | Feature |
|-------|---------|
| `GET /db` | SQLite CRUD demo |
| `POST /db/add` | Insert with zzz_db ORM |
| `GET /pg` | PostgreSQL CRUD demo (optional) |

### Background Jobs

| Route | Feature |
|-------|---------|
| `GET /jobs` | Job queue dashboard |
| `POST /jobs/enqueue` | Enqueue background job |
| `GET /jobs/stats` | Queue statistics |

## Middleware Stack

The app uses 11 middleware in its pipeline:

1. Error handler (with debug details)
2. Logging
3. GZIP compression
4. Request ID
5. CORS
6. htmx support
7. Body parser (JSON/form/multipart/text)
8. Session management
9. CSRF protection
10. Static file serving
11. Swagger UI

## Project Structure

```
example_app/
  src/
    main.zig                  # Route aggregation & server setup
    controllers/
      home.zig                # Home, about pages
      api.zig                 # REST API & Swagger
      auth.zig                # Auth demos
      sessions.zig            # Sessions & cookies
      htmx.zig                # htmx demos
      db.zig                  # SQLite CRUD
      pg.zig                  # PostgreSQL CRUD
      jobs.zig                # Background jobs
      ws.zig                  # WebSocket & channels
      misc.zig                # File download, errors
    templates/
      layout.html.zzz         # Main layout
      index.html.zzz          # Home page
      partials/
        nav.html.zzz          # Navigation
  public/
    css/style.css
    js/app.js
  certs/                       # Dev TLS certificates
  docker-compose.yml           # PostgreSQL + Adminer
```

## Requirements

- Zig 0.16.0-dev.2535+b5bd49460 or later
- SQLite3 (`libsqlite3-dev` on Linux)
- PostgreSQL (optional, via Docker Compose)
- OpenSSL 3 (optional, for TLS)

## License

MIT License - Copyright (c) 2026 Ivan Stamenkovic

# 🚀 Node.js REST API

A simple demo REST API built with Node.js and Express, featuring JWT authentication, MySQL, and Redis.

---

## 📦 Tech Stack

| Layer | Technology |
|---|---|
| Runtime | Node.js (ESM, `type: "module"`) |
| Framework | Express 5 |
| Database | MySQL 8 (via `mysql2`) |
| Cache / Sessions | Redis 7 |
| Auth | JWT (access + refresh tokens) |
| Password Hashing | bcrypt |
| Logging | Winston |
| Containerization | Docker + Docker Compose |

---

## 🗂️ Project Structure

```
nodeapi/
├── server.js                        # Entry point – Express app & all route definitions
├── config/
│   ├── db.js                        # MySQL connection pool + DB helper methods
│   └── redis.js                     # Redis client setup & connection
├── controllers/
│   └── error_controller.js          # Centralised error response helper (sendError)
├── middleware/
│   └── auth.js                      # JWT verification + token blacklist check
├── utils/
│   ├── error_response.js            # Error message constants
│   ├── id_generator.js              # Prefixed random alphanumeric ID generator
│   ├── logger.js                    # Winston logger (IST timestamps, file + console)
│   └── custom-migration-manager.js  # Custom SQL migration CLI tool
├── migrations/
│   └── sqls/                        # SQL migration files (<timestamp>-<name>-up/down.sql)
├── logs/                            # Runtime log output (error.log, combined.log)
├── Dockerfile                       # Multi-stage Docker build
├── docker-compose.yml               # Full stack: API + MySQL + Redis
├── health-check.sh                  # Container health check script
├── .env.example                     # Local development environment template
└── .env.docker-example              # Docker/production environment template
```

---

## ⚡ Quick Start

### Prerequisites

- Node.js ≥ 18
- MySQL 8 (running locally or via Docker)
- Redis 7 (running locally or via Docker)

### Local Setup

```bash
# 1. Clone the repo
git clone <repo-url>
cd nodeapi

# 2. Install dependencies
npm install

# 3. Configure environment
cp .env.example .env
# Edit .env with your DB credentials, Redis host, and JWT secret

# 4. Apply database migrations
npm run "db:migrate apply"

# 5. Start the server
npm start
```

The server starts on the port defined in `.env` (default: `5000`).

---

## 🐳 Docker Setup

The Docker Compose stack brings up the API, MySQL, and Redis together. MySQL and Redis are **not** exposed externally — only the API port is published.

```bash
# 1. Configure the Docker environment
cp .env.docker-example .env
# Edit .env if you want to change credentials

# 2. Build the image
docker build -t my-node-api:latest .

# 3. Start the full stack
docker compose up -d

# 4. Verify health
bash health-check.sh
```

**What happens on startup:**  
The API container waits for MySQL to be ready (via `nc`), then automatically runs pending migrations, and finally starts the Express server.

---

## 🔌 API Reference

All routes are prefixed with `/api`. Protected routes require a valid `Authorization: Bearer <accessToken>` header.

### Auth

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `POST` | `/api/register` | ❌ | Register a new user |
| `POST` | `/api/login` | ❌ | Login – returns access + refresh tokens |
| `POST` | `/api/refresh-token` | ❌ | Exchange refresh token for a new access token |
| `POST` | `/api/logout` | ✅ | Invalidate tokens and blacklist the session |

### User

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `GET` | `/api/profile` | ✅ | Get current user's profile (password excluded) |
| `GET` | `/api/users` | ✅ | List all users |
| `DELETE` | `/api/user/delete` | ✅ | Delete a user account by `user_id` |

### Utility

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `GET` | `/api/health` | ❌ | Health check – returns `{ status: "OK", timestamp }` |
| `GET` | `/api/protected` | ✅ | Minimal protected route for auth validation |

### Request / Response Examples

**Register**
```http
POST /api/register
Content-Type: application/json

{
  "username": "rahul",
  "mail_id": "rahul@example.com",
  "password": "securepassword"
}
```
```json
{ "success": true, "message": "User registered successfully!" }
```

**Login**
```http
POST /api/login
Content-Type: application/json

{ "mail_id": "rahul@example.com", "password": "securepassword" }
```
```json
{
  "success": true,
  "accessToken": "<jwt>",
  "refreshToken": "<jwt>"
}
```

**Refresh Token**
```http
POST /api/refresh-token
Authorization: Bearer <refreshToken>
```
```json
{ "newAccessToken": "<jwt>" }
```

**Logout**
```http
POST /api/logout
Authorization: Bearer <accessToken>
```
```json
{ "message": "Logged out successfully" }
```

**Delete User**
```http
DELETE /api/user/delete
Authorization: Bearer <accessToken>
Content-Type: application/json

{ "user_id": "USRxxxxxxxx" }
```
```json
{ "message": "User deleted successfully" }
```

---

## 🔐 Authentication Flow

```
Client                          API                        Redis
  │                              │                            │
  │── POST /api/login ──────────►│                            │
  │                              │── SET refresh:<user_id> ──►│
  │◄── { accessToken, refreshToken }                          │
  │                              │                            │
  │── (protected request) ──────►│                            │
  │   Authorization: Bearer <at> │── GET bl_<token> ─────────►│
  │                              │◄── (not blacklisted) ──────│
  │◄── 200 OK ──────────────────│                            │
  │                              │                            │
  │── POST /api/logout ─────────►│                            │
  │                              │── DEL refresh:<user_id> ──►│
  │                              │── SET bl_<token> (15m) ───►│
  │◄── { message: "Logged out" } │                            │
```

- **Access tokens** expire per `JWT_ACCESS_EXPIRES` (default: `1h`).
- **Refresh tokens** are stored in Redis under `refresh:<user_id>` and expire after `JWT_REFRESH_EXPIRES` (default: `7d`).
- **Logout** deletes the refresh token from Redis and blacklists the access token for 15 minutes under `bl_<token>`.
- **Every protected request** checks the blacklist in Redis before verifying the JWT signature.

---

## 🗃️ Database

### Schema

```sql
CREATE TABLE IF NOT EXISTS users (
  id        INT AUTO_INCREMENT PRIMARY KEY,
  user_id   VARCHAR(100) NOT NULL UNIQUE,   -- Prefixed ID e.g. USRa1b2c3
  username  VARCHAR(255) NOT NULL UNIQUE,
  password  VARCHAR(255) NOT NULL,          -- bcrypt hash (cost factor 10)
  mail_id   VARCHAR(255) NOT NULL UNIQUE
);
```

### User ID Generation

User IDs are generated by `utils/id_generator.js` using the prefix defined in `USER_IDS` (default: `USR`) followed by 6 random characters drawn from the `CHARACTERS` alphabet.

Example: `USRk9X3mQ`

---

## 🔄 Database Migrations

The project ships with a **custom migration manager** (`utils/custom-migration-manager.js`) that tracks applied migrations in a dedicated MySQL table.

### Commands

```bash
# Apply all pending migrations
npm run "db:migrate apply"

# Rollback the most recent migration
npm run "db:migrate rollback"

# Rollback a specific named migration
npm run "db:migrate rollback" <migration-name>

# Create a new migration (generates up + down SQL files)
npm run "db:migrate create" <name>

# List all applied migrations
npm run "db:migrate list"
```

### Migration File Convention

Files live in `migrations/sqls/` and follow this naming pattern:

```
<YYYYMMDDHHMMSS>-<name>-up.sql      ← forward migration
<YYYYMMDDHHMMSS>-<name>-down.sql    ← rollback migration
```

Each applied migration's name and a SHA-256 hash of its SQL are recorded in the tracking table (configured via `TRACKING_TABLE`).

---

## 📝 Logging

Winston is used for structured logging with:

- **Console transport** – pretty-printed with IST timestamps.
- **`logs/error.log`** – `error` level only.
- **`logs/combined.log`** – all levels.

Log format: `[YYYY-MM-DDTHH:MM:SS.ms IST] LEVEL: message`

---

## 🌱 Environment Variables

Copy `.env.example` for local development or `.env.docker-example` for Docker.

| Variable | Description | Default |
|----------|-------------|---------|
| `PORT` | Server port | `5000` |
| `DB_HOST` | MySQL host | `localhost` |
| `DB_USER` | MySQL username | — |
| `DB_PASSWORD` | MySQL password | — |
| `DB_NAME` | MySQL database name | — |
| `DB_PORT` | MySQL port | `3306` |
| `REDIS_HOST` | Redis host | `127.0.0.1` |
| `REDIS_PORT` | Redis port | `6379` |
| `JWT_SECRET` | Secret key for signing JWTs | — |
| `JWT_ACCESS_EXPIRES` | Access token TTL | `1h` |
| `JWT_REFRESH_EXPIRES` | Refresh token TTL | `7d` |
| `USER_IDS` | Prefix for generated user IDs | `USR` |
| `CHARACTERS` | Alphabet for ID generation | `ABCDE...Z0-9` |
| `TRACKING_TABLE` | Migration tracking table name | `migrations` |
| `MIGRATIONS_DIR` | Path to SQL migration files | `migrations/sqls` |

> ⚠️ **Never commit your real `.env` file.** Use a secrets manager in production and rotate `JWT_SECRET` regularly.

---

## 🐋 Docker Details

The `Dockerfile` uses a **multi-stage build**:

1. **Build stage** (`node:lts-slim`) – installs production-only dependencies.
2. **Production stage** (`node:lts-slim`) – copies the built artefact, creates a dedicated non-root `appuser`, and runs the server.

`netcat-openbsd` is installed in the production image so the Compose `command` can wait for MySQL to become available before starting.

---

## 📋 npm Scripts

| Script | Command | Description |
|--------|---------|-------------|
| `start` | `node server.js` | Start the production server |
| `db:migrate apply` | `node ./utils/custom-migration-manager.js apply` | Apply pending migrations |
| `db:migrate rollback` | `node ./utils/custom-migration-manager.js rollback` | Rollback last migration |
| `db:migrate create` | `node ./utils/custom-migration-manager.js create` | Create new migration files |
| `db:migrate list` | `node ./utils/custom-migration-manager.js list` | List applied migrations |
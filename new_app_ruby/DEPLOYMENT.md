# Deployment Guide

<p align="center">
  <img src="https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker" />
  <img src="https://img.shields.io/badge/GitHub_Actions-2088FF?style=for-the-badge&logo=github-actions&logoColor=white" alt="GitHub Actions" />
  <img src="https://img.shields.io/badge/Azure-0078D4?style=for-the-badge&logo=microsoft-azure&logoColor=white" alt="Azure" />
  <img src="https://img.shields.io/badge/GHCR-181717?style=for-the-badge&logo=github&logoColor=white" alt="GHCR" />
</p>

---

This guide covers local development with Docker and production deployment via CI/CD.

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `SESSION_SECRET` | Secret key for session encryption (64+ hex chars) | Yes |
| `DATABASE_URL` | PostgreSQL connection string | Yes |
| `POSTGRES_USER` | Database username | Yes |
| `POSTGRES_PASSWORD` | Database password | Yes |
| `POSTGRES_DB` | Database name | Yes |
| `RACK_ENV` | Environment (`development`, `test`, `production`) | No |

### Generate a Session Secret

```bash
ruby -r securerandom -e 'puts SecureRandom.hex(64)'
```

### Example `.env` File

```env
SESSION_SECRET=your-64-char-hex-secret-here
POSTGRES_USER=whoknows
POSTGRES_PASSWORD=your-secure-password-here
POSTGRES_DB=whoknows
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
DATABASE_URL=postgresql://whoknows:your-secure-password-here@localhost:5432/whoknows
```

## Local Development with Docker

### Option 1: Full Stack (Recommended)

Run the entire stack with Docker Compose:

```bash
cd new_app_ruby

# Start all services
docker compose up -d

# View logs
docker compose logs -f

# Stop all services
docker compose down
```

Services:
- **App**: http://localhost:80 (via Nginx)
- **PostgreSQL**: localhost:5432

### Option 2: Database Only

Run only PostgreSQL in Docker, app locally:

```bash
# Start PostgreSQL
docker run -d --name whoknows-postgres \
  -p 5432:5432 \
  -e POSTGRES_DB=whoknows \
  -e POSTGRES_USER=whoknows \
  -e POSTGRES_PASSWORD=your-secure-password-here \
  postgres:17

# Run app locally
bundle exec ruby app.rb
```

App available at http://localhost:8080

## Docker Compose Architecture

```yaml
services:
  db:          # PostgreSQL 17
  app:         # Ruby/Sinatra application
  nginx:       # Reverse proxy with SSL
```

```
Internet
    │
    ▼
┌─────────┐     ┌─────────┐     ┌─────────┐
│  Nginx  │────▶│   App   │────▶│ Postgres│
│ :80/443 │     │  :8080  │     │  :5432  │
└─────────┘     └─────────┘     └─────────┘
```

## CI/CD Pipeline

### Workflow Overview

```
Push to main
     │
     ▼
┌─────────────────┐
│  Build & Push   │
│  Docker Image   │
│    to GHCR      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Deploy to      │
│  Azure VM       │
│  via SSH        │
└─────────────────┘
```

### GitHub Actions Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `ruby-tests.yml` | Push to `dev`, `main` | Run RSpec tests |
| `deploy-workflow.yml` | Push to `main` | Build, push, deploy |

### Required Secrets

Configure these in GitHub repository settings:

| Secret | Description |
|--------|-------------|
| `GHCR_PULL_TOKEN` | GitHub token for container registry |
| `AZURE_SSH_PRIVATE_KEY` | SSH key for Azure VM |
| `AZURE_HOST` | Azure VM hostname/IP |
| `AZURE_USER` | SSH username |
| `SESSION_SECRET` | App session secret |
| `POSTGRES_PASSWORD` | Database password |

## Production Deployment

### Manual Deployment

If you need to deploy manually:

```bash
# SSH into server
ssh user@your-server

# Navigate to app directory
cd ~/app/whoknows/new_app_ruby

# Pull latest images
docker compose pull

# Restart services
docker compose up -d --remove-orphans

# Check status
docker compose ps
```

### Rollback

To rollback to a previous version:

```bash
# List available image tags
docker images ghcr.io/devops-valgfag/app-whoknows

# Update docker-compose.yml to use specific tag
# image: ghcr.io/devops-valgfag/app-whoknows:sha-abc123

# Restart
docker compose up -d
```

## Monitoring

### Health Checks

The application exposes:

| Endpoint | Description |
|----------|-------------|
| `/metrics` | Prometheus metrics |
| `/api/search?q=test` | Functional health check |

### Prometheus Metrics

Available metrics:
- `whoknows_search_total` - Total searches by language
- `whoknows_search_with_match_total` - Searches with results
- `whoknows_registered_users_total` - User registrations
- `whoknows_login_total` - Successful logins

### View Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f app

# Last 100 lines
docker compose logs --tail=100 app
```

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker compose logs app

# Check if port is in use
netstat -tulpn | grep 8080

# Rebuild without cache
docker compose build --no-cache
docker compose up -d
```

### Database Connection Issues

```bash
# Check if PostgreSQL is running
docker compose ps db

# Test connection
docker compose exec db psql -U whoknows -d whoknows -c "SELECT 1"

# Check DATABASE_URL format
# postgresql://user:password@host:port/database
```

### Permission Issues

```bash
# Check file permissions
ls -la

# Fix ownership if needed
sudo chown -R $USER:$USER .
```

## SSL/TLS Setup

For production HTTPS, place certificates in:

```
new_app_ruby/
└── certs/
    ├── fullchain.pem
    └── privkey.pem
```

Nginx is pre-configured to use these certificates.

---

<p align="center">
  <img src="https://img.shields.io/badge/Ship_It!-success?style=flat-square" alt="Ship It" />
</p>

# Docker Deployment Guide for Claudable

This guide explains how to build and deploy Claudable using Docker.

## Prerequisites

- Docker 20.10+ installed
- Docker Compose 2.0+ (optional, for easier deployment)
- At least 2GB of free disk space

## Quick Start with Docker Compose

The easiest way to run Claudable with Docker:

```bash
# 1. Clone the repository (if not already done)
git clone https://github.com/opactorai/Claudable.git
cd Claudable

# 2. Create environment file (optional)
cp .env .env.docker
# Edit .env.docker with your configurations

# 3. Start the application
docker-compose up -d

# 4. View logs
docker-compose logs -f

# 5. Access the application
# Open http://localhost:3000 in your browser
```

## Manual Docker Build

### Build the Image

```bash
# Build with default tag
docker build -t claudable:latest .

# Build with custom tag
docker build -t claudable:v2.0.0 .
```

### Run the Container

```bash
# Basic run with default settings
docker run -d \
  --name claudable \
  -p 3000:3000 \
  -p 3100-3200:3100-3200 \
  -v claudable-data:/app/data \
  claudable:latest

# Run with custom environment variables
docker run -d \
  --name claudable \
  -p 3000:3000 \
  -p 3100-3200:3100-3200 \
  -e DATABASE_URL=file:/app/data/cc.db \
  -e PROJECTS_DIR=/app/data/projects \
  -e ENCRYPTION_KEY=your-secure-key-here \
  -e NEXT_PUBLIC_APP_URL=http://localhost:3000 \
  -v claudable-data:/app/data \
  claudable:latest
```

## Environment Variables

### Required Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DATABASE_URL` | SQLite database path | `file:/app/data/cc.db` |
| `PROJECTS_DIR` | Projects storage directory | `/app/data/projects` |
| `ENCRYPTION_KEY` | Encryption key for sensitive data | (must be set) |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PORT` | Application port | `3000` |
| `WEB_PORT` | Web server port | `3000` |
| `NEXT_PUBLIC_APP_URL` | Public application URL | `http://localhost:3000` |
| `PREVIEW_PORT_START` | Preview port range start | `3100` |
| `PREVIEW_PORT_END` | Preview port range end | `3200` |
| `NODE_ENV` | Node environment | `production` |

### Security Note

**IMPORTANT**: Change the `ENCRYPTION_KEY` in production! Generate a secure key:

```bash
# Generate a secure 32-byte encryption key
openssl rand -hex 32
```

## Docker Compose Configuration

The `docker-compose.yml` file provides an easy way to manage Claudable:

```yaml
# Start services
docker-compose up -d

# Stop services
docker-compose down

# View logs
docker-compose logs -f

# Restart services
docker-compose restart

# Remove everything (including volumes)
docker-compose down -v
```

### Custom Configuration

Create a `.env` file in the project root to customize settings:

```env
# Application
PORT=3000
WEB_PORT=3000
NEXT_PUBLIC_APP_URL=http://localhost:3000

# Database
DATABASE_URL=file:/app/data/cc.db

# Directories
PROJECTS_DIR=/app/data/projects

# Security (CHANGE THIS!)
ENCRYPTION_KEY=your-secure-32-byte-hex-key-here

# Preview ports
PREVIEW_PORT_START=3100
PREVIEW_PORT_END=3200
```

## Volume Management

### Data Persistence

All data is stored in the `/app/data` volume, which includes:
- SQLite database (`cc.db`)
- Project files (`projects/`)
- Backups (`backups/`)

### Backup Data

```bash
# Create backup of the volume
docker run --rm \
  -v claudable-data:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/claudable-backup-$(date +%Y%m%d).tar.gz -C /data .
```

### Restore Data

```bash
# Restore from backup
docker run --rm \
  -v claudable-data:/data \
  -v $(pwd):/backup \
  alpine sh -c "cd /data && tar xzf /backup/claudable-backup-YYYYMMDD.tar.gz"
```

### Inspect Volume

```bash
# View volume contents
docker run --rm \
  -v claudable-data:/data \
  alpine ls -la /data
```

## Port Configuration

### Default Ports

- **3000**: Main application (Next.js server)
- **3100-3200**: Preview servers for generated projects

### Custom Port Mapping

```bash
# Run on port 8080 instead of 3000
docker run -d \
  --name claudable \
  -p 8080:3000 \
  -p 3100-3200:3100-3200 \
  -e PORT=3000 \
  -e NEXT_PUBLIC_APP_URL=http://localhost:8080 \
  -v claudable-data:/app/data \
  claudable:latest
```

## Health Checks

The container includes a health check that monitors application status:

```bash
# Check container health
docker inspect --format='{{.State.Health.Status}}' claudable

# View health check logs
docker inspect --format='{{json .State.Health}}' claudable | jq
```

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker logs claudable

# Check if port is already in use
lsof -i :3000

# Remove and recreate container
docker rm -f claudable
docker-compose up -d
```

### Database Issues

```bash
# Access container shell
docker exec -it claudable sh

# Check database
cd /app/data
ls -la cc.db

# Reset database (WARNING: destroys data)
docker exec -it claudable npx prisma migrate reset
```

### Permission Issues

```bash
# Fix volume permissions
docker run --rm \
  -v claudable-data:/data \
  alpine chown -R 1001:1001 /data
```

### Out of Disk Space

```bash
# Check Docker disk usage
docker system df

# Clean up unused images and containers
docker system prune -a

# Remove unused volumes
docker volume prune
```

## Production Deployment

### Security Checklist

- [ ] Change `ENCRYPTION_KEY` to a secure random value
- [ ] Use HTTPS with reverse proxy (nginx, Traefik, Caddy)
- [ ] Set appropriate resource limits
- [ ] Configure log rotation
- [ ] Enable container restart policies
- [ ] Use Docker secrets for sensitive data
- [ ] Regularly backup volumes
- [ ] Keep Docker and images updated

### Reverse Proxy Example (nginx)

```nginx
server {
    listen 80;
    server_name claudable.example.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Resource Limits

Add resource constraints to `docker-compose.yml`:

```yaml
services:
  claudable:
    # ... other configuration ...
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          cpus: '1'
          memory: 512M
```

## Monitoring

### View Real-time Logs

```bash
# All logs
docker-compose logs -f

# Last 100 lines
docker-compose logs --tail=100

# Specific service
docker-compose logs -f claudable
```

### Container Stats

```bash
# Real-time stats
docker stats claudable

# One-time stats
docker stats --no-stream claudable
```

## Updating

### Update to Latest Version

```bash
# Pull latest code
git pull origin main

# Rebuild image
docker-compose build --no-cache

# Restart with new image
docker-compose up -d

# Clean up old images
docker image prune
```

### Rollback to Previous Version

```bash
# Stop current container
docker-compose down

# Run previous image version
docker run -d \
  --name claudable \
  -p 3000:3000 \
  -v claudable-data:/app/data \
  claudable:v1.0.0
```

## Development with Docker

### Build for Development

```bash
# Build with development target (if added to Dockerfile)
docker build --target development -t claudable:dev .

# Run with hot reload
docker run -d \
  --name claudable-dev \
  -p 3000:3000 \
  -v $(pwd):/app \
  -v /app/node_modules \
  claudable:dev npm run dev
```

## Support

For issues related to Docker deployment:
1. Check logs: `docker logs claudable`
2. Review environment variables: `docker exec claudable env`
3. Verify volume mounts: `docker inspect claudable`
4. Check health status: `docker inspect --format='{{.State.Health.Status}}' claudable`

For application-specific issues, see the main [README.md](../README.md) and [troubleshooting section](../README.md#troubleshooting).

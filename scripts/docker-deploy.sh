#!/bin/bash

# Claudable Docker Deployment Script
# This script helps you quickly deploy Claudable using Docker

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check Docker installation
if ! command_exists docker; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

print_success "Docker is installed"

# Check Docker Compose
if ! command_exists docker-compose && ! docker compose version >/dev/null 2>&1; then
    print_warning "Docker Compose not found. Will use docker commands instead."
    USE_COMPOSE=false
else
    print_success "Docker Compose is available"
    USE_COMPOSE=true
fi

# Welcome message
echo ""
echo "=================================================="
echo "  Claudable Docker Deployment"
echo "=================================================="
echo ""

# Check if .env file exists
if [ ! -f .env ]; then
    print_warning ".env file not found. Creating from template..."

    # Generate secure encryption key
    ENCRYPTION_KEY=$(openssl rand -hex 32 2>/dev/null || echo "default-insecure-key-please-change-this-immediately")

    cat > .env << EOF
# Auto-generated Docker environment configuration
DATABASE_URL="file:/app/data/cc.db"
PROJECTS_DIR="/app/data/projects"
ENCRYPTION_KEY="${ENCRYPTION_KEY}"
PORT=3000
WEB_PORT=3000
NEXT_PUBLIC_APP_URL="http://localhost:3000"
PREVIEW_PORT_START=3100
PREVIEW_PORT_END=3200
NODE_ENV=production
EOF

    print_success ".env file created with secure encryption key"
    print_warning "Please review .env file before deploying to production!"
else
    print_success ".env file exists"
fi

# Deployment options
echo ""
print_info "Select deployment option:"
echo "  1) Deploy with Docker Compose (recommended)"
echo "  2) Deploy with Docker commands"
echo "  3) Build image only"
echo "  4) Exit"
echo ""
read -p "Enter choice [1-4]: " choice

case $choice in
    1)
        if [ "$USE_COMPOSE" = false ]; then
            print_error "Docker Compose is not available. Please choose option 2."
            exit 1
        fi

        print_info "Deploying with Docker Compose..."

        # Check if docker-compose.yml exists
        if [ ! -f docker-compose.yml ]; then
            print_error "docker-compose.yml not found!"
            exit 1
        fi

        # Build and start
        print_info "Building image..."
        docker-compose build

        print_info "Starting services..."
        docker-compose up -d

        print_success "Deployment complete!"

        # Show status
        echo ""
        print_info "Container status:"
        docker-compose ps

        # Show logs
        echo ""
        print_info "Recent logs:"
        docker-compose logs --tail=20

        echo ""
        print_success "Claudable is running!"
        print_info "Access the application at: http://localhost:3000"
        print_info "View logs: docker-compose logs -f"
        print_info "Stop services: docker-compose down"
        ;;

    2)
        print_info "Deploying with Docker commands..."

        # Build image
        print_info "Building image..."
        docker build -t claudable:latest .

        # Stop and remove existing container
        if docker ps -a | grep -q claudable; then
            print_info "Stopping existing container..."
            docker stop claudable 2>/dev/null || true
            docker rm claudable 2>/dev/null || true
        fi

        # Create volume if it doesn't exist
        if ! docker volume ls | grep -q claudable-data; then
            print_info "Creating volume..."
            docker volume create claudable-data
        fi

        # Run container
        print_info "Starting container..."
        docker run -d \
            --name claudable \
            --restart unless-stopped \
            -p 3000:3000 \
            -p 3100-3200:3100-3200 \
            --env-file .env \
            -v claudable-data:/app/data \
            claudable:latest

        print_success "Deployment complete!"

        # Show status
        echo ""
        print_info "Container status:"
        docker ps -f name=claudable

        # Show logs
        echo ""
        print_info "Recent logs:"
        docker logs --tail=20 claudable

        echo ""
        print_success "Claudable is running!"
        print_info "Access the application at: http://localhost:3000"
        print_info "View logs: docker logs -f claudable"
        print_info "Stop container: docker stop claudable"
        ;;

    3)
        print_info "Building Docker image only..."
        docker build -t claudable:latest .
        print_success "Image built successfully!"

        echo ""
        print_info "To run the image:"
        echo "  docker run -d --name claudable -p 3000:3000 -v claudable-data:/app/data claudable:latest"
        ;;

    4)
        print_info "Exiting..."
        exit 0
        ;;

    *)
        print_error "Invalid choice. Exiting..."
        exit 1
        ;;
esac

echo ""
print_info "For more information, see: claudedocs/DOCKER_DEPLOYMENT.md"

#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Starting ERPNext Installation Script${NC}"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if docker compose is available
if ! docker compose version &> /dev/null; then
    echo "Docker compose is not available. Please make sure Docker is properly installed."
    exit 1
fi

# Commented because we assume the frappe_docker directory is already cloned
# # Create directory for frappe_docker
# echo -e "${GREEN}Creating and setting up frappe_docker directory...${NC}"
# git clone https://github.com/frappe/frappe_docker.git
# cd frappe_docker

# Copy devcontainer configuration
echo -e "${GREEN}Setting up development configuration...${NC}"
cp -R devcontainer-example .devcontainer

# Create development directory
mkdir -p development

# Set up the environment in the container
echo -e "${GREEN}Creating and starting development containers...${NC}"
docker compose -f .devcontainer/docker-compose.yml up -d

# Wait for containers to be ready
echo "Waiting for containers to be ready..."
sleep 10

# Execute commands inside the container
echo -e "${GREEN}Setting up Frappe bench...${NC}"
docker exec -i devcontainer-frappe-1 bash << 'EOF'
cd /workspace/development
bench init --skip-redis-config-generation --frappe-branch version-15 frappe-bench
cd frappe-bench

# Configure bench
bench set-config -g db_host mariadb
bench set-config -g redis_cache redis://redis-cache:6379
bench set-config -g redis_queue redis://redis-queue:6379
bench set-config -g redis_socketio redis://redis-queue:6379

# Create new site
bench new-site --db-root-password 123 --admin-password admin development.localhost

# Get and install ERPNext
bench get-app --branch version-15 --resolve-deps erpnext
bench --site development.localhost install-app erpnext

# Get and install Payments app
bench get-app --branch version-15 --resolve-deps payments
bench --site development.localhost install-app payments

# Set developer mode
bench --site development.localhost set-config developer_mode 1
bench --site development.localhost clear-cache
EOF

echo -e "${GREEN}Installation completed!${NC}"
echo -e "${BLUE}You can now access your ERPNext instance at: http://development.localhost:8000${NC}"
echo -e "${BLUE}Username: Administrator${NC}"
echo -e "${BLUE}Password: admin${NC}"
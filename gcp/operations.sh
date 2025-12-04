#!/bin/bash
# Operations Script for sora2api on GCP
# Usage: ./operations.sh <command> [options]

set -e

# Default configuration
PROJECT_ID="${PROJECT_ID:-nooka-cloudrun-250627}"
ZONE="${ZONE:-us-central1-a}"
INSTANCE_NAME="${INSTANCE_NAME:-sora2api-vm}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Functions
show_help() {
    echo "sora2api Operations Script"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  ssh              SSH into the VM"
    echo "  logs [service]   View logs (sora2api or warp, default: all)"
    echo "  restart          Restart all services"
    echo "  update           Pull latest Docker images and restart"
    echo "  code-update      Pull latest code from GitHub and restart"
    echo "  backup           Backup data and config"
    echo "  status           Show service status"
    echo "  ip               Show external IP address"
    echo "  config           Edit configuration file"
    echo "  stop             Stop all services"
    echo "  start            Start all services"
    echo ""
    echo "Environment Variables:"
    echo "  PROJECT_ID       GCP Project ID (default: nooka-cloudrun-250627)"
    echo "  ZONE             GCP Zone (default: us-central1-a)"
    echo "  INSTANCE_NAME    VM instance name (default: sora2api-vm)"
}

run_ssh() {
    gcloud compute ssh "$INSTANCE_NAME" --zone="$ZONE" --project="$PROJECT_ID" "$@"
}

run_remote() {
    gcloud compute ssh "$INSTANCE_NAME" --zone="$ZONE" --project="$PROJECT_ID" --command="$1"
}

cmd_ssh() {
    echo -e "${GREEN}Connecting to $INSTANCE_NAME...${NC}"
    run_ssh
}

cmd_logs() {
    local service="${1:-}"
    echo -e "${GREEN}Fetching logs...${NC}"
    if [ -z "$service" ]; then
        run_remote "cd /opt/sora2api && docker compose logs -f --tail=100"
    else
        run_remote "cd /opt/sora2api && docker compose logs -f --tail=100 $service"
    fi
}

cmd_restart() {
    echo -e "${YELLOW}Restarting services...${NC}"
    run_remote "cd /opt/sora2api && docker compose restart"
    echo -e "${GREEN}Services restarted${NC}"
}

cmd_update() {
    echo -e "${YELLOW}Updating Docker images...${NC}"
    run_remote "cd /opt/sora2api && docker compose pull && docker compose up -d"
    echo -e "${GREEN}Services updated${NC}"
}

cmd_code_update() {
    echo -e "${YELLOW}Updating code from GitHub...${NC}"
    run_remote "cd /opt/sora2api/repo && git pull"
    echo -e "${YELLOW}Restarting services...${NC}"
    run_remote "cd /opt/sora2api && docker compose restart sora2api"
    echo -e "${GREEN}Code updated and services restarted${NC}"
}

cmd_backup() {
    local backup_dir="./backups"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_name="sora2api_backup_${timestamp}"

    mkdir -p "$backup_dir"

    echo -e "${YELLOW}Creating backup...${NC}"

    # Backup config
    echo "Backing up configuration..."
    gcloud compute scp --zone="$ZONE" --project="$PROJECT_ID" \
        "$INSTANCE_NAME:/opt/sora2api/config/setting.toml" \
        "$backup_dir/${backup_name}_setting.toml"

    # Backup database
    echo "Backing up database..."
    gcloud compute scp --zone="$ZONE" --project="$PROJECT_ID" \
        "$INSTANCE_NAME:/opt/sora2api/data/hancat.db" \
        "$backup_dir/${backup_name}_hancat.db" 2>/dev/null || echo "No database file found (may be new installation)"

    echo -e "${GREEN}Backup completed: $backup_dir/${backup_name}_*${NC}"
}

cmd_status() {
    echo -e "${GREEN}=== Service Status ===${NC}"
    run_remote "cd /opt/sora2api && docker compose ps"
    echo ""
    echo -e "${GREEN}=== Container Health ===${NC}"
    run_remote "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
    echo ""
    echo -e "${GREEN}=== Resource Usage ===${NC}"
    run_remote "docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}'"
}

cmd_ip() {
    local ip=$(gcloud compute instances describe "$INSTANCE_NAME" \
        --zone="$ZONE" \
        --project="$PROJECT_ID" \
        --format='get(networkInterfaces[0].accessConfigs[0].natIP)')
    echo -e "${GREEN}External IP: $ip${NC}"
    echo "Service URL: http://$ip:8000"
    echo "Admin Panel: http://$ip:8000/admin"
}

cmd_config() {
    echo -e "${YELLOW}Opening configuration editor...${NC}"
    run_ssh -- "sudo nano /opt/sora2api/config/setting.toml"
    echo ""
    read -p "Restart services to apply changes? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cmd_restart
    fi
}

cmd_stop() {
    echo -e "${YELLOW}Stopping services...${NC}"
    run_remote "cd /opt/sora2api && docker compose down"
    echo -e "${GREEN}Services stopped${NC}"
}

cmd_start() {
    echo -e "${YELLOW}Starting services...${NC}"
    run_remote "cd /opt/sora2api && docker compose up -d"
    echo -e "${GREEN}Services started${NC}"
}

# Main
case "${1:-}" in
    ssh)
        cmd_ssh
        ;;
    logs)
        cmd_logs "$2"
        ;;
    restart)
        cmd_restart
        ;;
    update)
        cmd_update
        ;;
    code-update)
        cmd_code_update
        ;;
    backup)
        cmd_backup
        ;;
    status)
        cmd_status
        ;;
    ip)
        cmd_ip
        ;;
    config)
        cmd_config
        ;;
    stop)
        cmd_stop
        ;;
    start)
        cmd_start
        ;;
    help|--help|-h|"")
        show_help
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac

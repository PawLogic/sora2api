#!/bin/bash
# GCP Deployment Script for sora2api
# Usage: ./deploy.sh [--project PROJECT_ID] [--zone ZONE] [--machine-type TYPE]

set -e

# Default configuration
PROJECT_ID="${PROJECT_ID:-nooka-cloudrun-250627}"
ZONE="${ZONE:-us-central1-a}"
MACHINE_TYPE="${MACHINE_TYPE:-e2-small}"
INSTANCE_NAME="${INSTANCE_NAME:-sora2api-vm}"
DISK_SIZE="${DISK_SIZE:-20}"
SERVICE_ACCOUNT="${SERVICE_ACCOUNT:-judy-12@nooka-cloudrun-250627.iam.gserviceaccount.com}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --project)
            PROJECT_ID="$2"
            shift 2
            ;;
        --zone)
            ZONE="$2"
            shift 2
            ;;
        --machine-type)
            MACHINE_TYPE="$2"
            shift 2
            ;;
        --instance-name)
            INSTANCE_NAME="$2"
            shift 2
            ;;
        --service-account-key)
            SERVICE_ACCOUNT_KEY="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --project PROJECT_ID       GCP Project ID (default: nooka-cloudrun-250627)"
            echo "  --zone ZONE                GCP Zone (default: us-central1-a)"
            echo "  --machine-type TYPE        VM machine type (default: e2-small)"
            echo "  --instance-name NAME       VM instance name (default: sora2api-vm)"
            echo "  --service-account-key FILE Path to service account key JSON"
            echo "  --help                     Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

echo -e "${GREEN}=== sora2api GCP Deployment ===${NC}"
echo "Project: $PROJECT_ID"
echo "Zone: $ZONE"
echo "Machine Type: $MACHINE_TYPE"
echo "Instance Name: $INSTANCE_NAME"
echo ""

# Authenticate if service account key provided
if [ -n "$SERVICE_ACCOUNT_KEY" ]; then
    echo -e "${YELLOW}Authenticating with service account...${NC}"
    gcloud auth activate-service-account --key-file="$SERVICE_ACCOUNT_KEY"
fi

# Set project
echo -e "${YELLOW}Setting GCP project...${NC}"
gcloud config set project "$PROJECT_ID"

# Check if instance already exists
if gcloud compute instances describe "$INSTANCE_NAME" --zone="$ZONE" &>/dev/null; then
    echo -e "${YELLOW}Instance $INSTANCE_NAME already exists.${NC}"
    read -p "Do you want to delete and recreate it? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Deleting existing instance...${NC}"
        gcloud compute instances delete "$INSTANCE_NAME" --zone="$ZONE" --quiet
    else
        echo -e "${RED}Deployment cancelled.${NC}"
        exit 1
    fi
fi

# Create firewall rule for port 8000 (if not exists)
echo -e "${YELLOW}Checking firewall rules...${NC}"
if ! gcloud compute firewall-rules describe allow-sora2api &>/dev/null; then
    echo -e "${YELLOW}Creating firewall rule for port 8000...${NC}"
    gcloud compute firewall-rules create allow-sora2api \
        --allow tcp:8000 \
        --target-tags sora2api \
        --description "Allow inbound traffic on port 8000 for sora2api"
else
    echo "Firewall rule 'allow-sora2api' already exists"
fi

# Get startup script path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STARTUP_SCRIPT="$SCRIPT_DIR/startup-script.sh"

if [ ! -f "$STARTUP_SCRIPT" ]; then
    echo -e "${RED}Error: startup-script.sh not found at $STARTUP_SCRIPT${NC}"
    exit 1
fi

# Create VM instance
echo -e "${YELLOW}Creating Compute Engine instance...${NC}"
gcloud compute instances create "$INSTANCE_NAME" \
    --zone="$ZONE" \
    --machine-type="$MACHINE_TYPE" \
    --image-family=ubuntu-2204-lts \
    --image-project=ubuntu-os-cloud \
    --boot-disk-size="${DISK_SIZE}GB" \
    --boot-disk-type=pd-balanced \
    --tags=sora2api \
    --service-account="$SERVICE_ACCOUNT" \
    --scopes=cloud-platform \
    --metadata-from-file=startup-script="$STARTUP_SCRIPT"

# Wait for instance to be running
echo -e "${YELLOW}Waiting for instance to start...${NC}"
sleep 10

# Get external IP
EXTERNAL_IP=$(gcloud compute instances describe "$INSTANCE_NAME" \
    --zone="$ZONE" \
    --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

echo ""
echo -e "${GREEN}=== Deployment Complete ===${NC}"
echo ""
echo "Instance: $INSTANCE_NAME"
echo "Zone: $ZONE"
echo "External IP: $EXTERNAL_IP"
echo ""
echo -e "${YELLOW}Important:${NC}"
echo "1. Wait 2-3 minutes for Docker installation and service startup"
echo "2. Access the service at: http://$EXTERNAL_IP:8000"
echo "3. Admin panel: http://$EXTERNAL_IP:8000/admin"
echo "4. Default credentials: admin / admin"
echo ""
echo -e "${YELLOW}Security Reminders:${NC}"
echo "- Change the default API key (han1234) in /opt/sora2api/config/setting.toml"
echo "- Change the default admin password"
echo "- Consider restricting firewall source IPs"
echo ""
echo -e "${YELLOW}Management Commands:${NC}"
echo "  SSH: gcloud compute ssh $INSTANCE_NAME --zone=$ZONE"
echo "  Logs: ./operations.sh logs"
echo "  Restart: ./operations.sh restart"

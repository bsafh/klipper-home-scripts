#!/bin/bash
# tailscale-service-check.sh
# Checks if all local services are running BEFORE starting tailscale serve/funnel
# Deploy this to A30 (192.168.80.47) and X5SA (192.168.80.53)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration per host
HOSTNAME=$(hostname)
if [[ "$HOSTNAME" == "a30" ]] || [[ "$HOSTNAME" == "klipper-a30" ]]; then
    HOST_TYPE="a30"
    SERVE_ADVERTISE="klipper-a30"
    FUNNEL_ADVERTISE="klipper-a30"
    SPOOLMAN_SERVICE="spoolman"
elif [[ "$HOSTNAME" == "x5sa" ]] || [[ "$HOSTNAME" == "klipper-x5sa" ]]; then
    HOST_TYPE="x5sa"
    SERVE_ADVERTISE="klipper-x5sa-t630"
    FUNNEL_ADVERTISE="klipper-x5sa-t630"
    SPOOLMAN_SERVICE="spoolman"
else
    echo -e "${RED}Unknown host: $HOSTNAME - assuming generic klipper${NC}"
    HOST_TYPE="generic"
    SERVE_ADVERTISE="klipper"
    FUNNEL_ADVERTISE="klipper"
    SPOOLMAN_SERVICE="spoolman"
fi

echo "=== Tailscale Service Check for $HOST_TYPE ($HOSTNAME) ==="

# Ports to check for local services (service_name:port)
# Format: "service_name:port:protocol" where protocol is tcp or http
declare -A REQUIRED_SERVICES=(
    ["klipper"]="7125:tcp"
    ["moonraker"]="7125:http"  # Moonraker HTTP API on same port
    ["nginx"]="80:http"
    ["nginx-https"]="443:https"
    ["spoolman"]="7912:http"
)

# Additional ports from rc.local that should be available
declare -A ADDITIONAL_PORTS=(
    ["81"]="http"
    ["7136"]="http"
    ["8080"]="http"
    ["8081"]="http"
    # ["8088"]="http"  # commented out in rc.local
)

# Tailscale funnel ports (external -> internal mapping)
declare -A FUNNEL_PORTS=(
    ["443"]="80"
    ["444"]="81"
    ["1000"]="81"
    ["7125"]="7125"
)

# Tailscale serve ports
declare -A SERVE_PORTS=(
    ["80"]="80"
    ["81"]="81"
    ["7912"]="7912"
    ["7125"]="7125"
    ["7136"]="7136"
    ["8080"]="8080"
    ["8081"]="8081"
)

# Function to check if a TCP port is listening
check_tcp_port() {
    local port=$1
    local service=$2
    if ss -tln | grep -q ":$port "; then
        echo -e "${GREEN}✓${NC} $service listening on TCP port $port"
        return 0
    else
        echo -e "${RED}✗${NC} $service NOT listening on TCP port $port"
        return 1
    fi
}

# Function to check HTTP endpoint
check_http_endpoint() {
    local port=$1
    local service=$2
    local path="${3:-/}"
    if curl -s -f -m 5 "http://localhost:$port$path" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $service HTTP endpoint responding on port $port"
        return 0
    else
        echo -e "${RED}✗${NC} $service HTTP endpoint NOT responding on port $port"
        return 1
    fi
}

# Function to check HTTPS endpoint
check_https_endpoint() {
    local port=$1
    local service=$2
    local path="${3:-/}"
    if curl -s -f -k -m 5 "https://localhost:$port$path" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $service HTTPS endpoint responding on port $port"
        return 0
    else
        echo -e "${RED}✗${NC} $service HTTPS endpoint NOT responding on port $port"
        return 1
    fi
}

# Check all required services
check_required_services() {
    local all_ok=true
    
    echo ""
    echo "=== Checking Required Local Services ==="
    
    for service in "${!REQUIRED_SERVICES[@]}"; do
        IFS=':' read -r port protocol <<< "${REQUIRED_SERVICES[$service]}"
        
        case $protocol in
            tcp)
                check_tcp_port "$port" "$service" || all_ok=false
                ;;
            http)
                check_http_endpoint "$port" "$service" || all_ok=false
                ;;
            https)
                check_https_endpoint "$port" "$service" || all_ok=false
                ;;
        esac
    done
    
    # Check additional ports (warn only, don't fail)
    echo ""
    echo "=== Checking Additional Ports (from rc.local) ==="
    for port in "${!ADDITIONAL_PORTS[@]}"; do
        protocol="${ADDITIONAL_PORTS[$port]}"
        case $protocol in
            http)
                check_http_endpoint "$port" "port-$port" || true
                ;;
            https)
                check_https_endpoint "$port" "port-$port" || true
                ;;
        esac
    done
    
    if [[ "$all_ok" == "true" ]]; then
        echo -e "\n${GREEN}All required services are running!${NC}"
        return 0
    else
        echo -e "\n${RED}Some required services are not running!${NC}"
        return 1
    fi
}

# Wait for services to be ready
wait_for_services() {
    local max_wait=120  # 2 minutes max
    local interval=5
    local elapsed=0
    
    echo "Waiting for local services to be ready (max ${max_wait}s)..."
    
    while [[ $elapsed -lt $max_wait ]]; do
        if check_required_services; then
            echo -e "${GREEN}Services ready after ${elapsed}s${NC}"
            return 0
        fi
        
        sleep $interval
        elapsed=$((elapsed + interval))
        echo -n "."
    done
    
    echo -e "\n${RED}Timeout waiting for services${NC}"
    return 1
}

# Start tailscaled
start_tailscaled() {
    echo ""
    echo "=== Starting tailscaled ==="
    
    if systemctl is-active --quiet tailscaled; then
        echo "tailscaled already running"
    else
        systemctl start tailscaled
        sleep 3
        if systemctl is-active --quiet tailscaled; then
            echo -e "${GREEN}tailscaled started${NC}"
        else
            echo -e "${RED}Failed to start tailscaled${NC}"
            return 1
        fi
    fi
    
    # Authenticate if needed
    if ! tailscale status | grep -q "Logged in"; then
        echo "Authenticating with Tailscale..."
        # Auth key should be in /home/klipper/printer_data/config/tailscale-auth.key
        if [[ -f /home/klipper/printer_data/config/tailscale-auth.key ]]; then
            AUTH_KEY=$(cat /home/klipper/printer_data/config/tailscale-auth.key)
            tailscale up --auth-key="$AUTH_KEY" --operator=klipper --ssh
        else
            echo -e "${YELLOW}No auth key found, trying existing auth...${NC}"
            tailscale up --operator=klipper --ssh
        fi
    fi
    
    # Wait for Tailscale to be fully up
    local count=0
    while ! tailscale status | grep -q "100\." && [[ $count -lt 30 ]]; do
        sleep 1
        count=$((count + 1))
    done
    
    if tailscale status | grep -q "100\."; then
        echo -e "${GREEN}Tailscale connected${NC}"
        return 0
    else
        echo -e "${RED}Tailscale failed to connect${NC}"
        return 1
    fi
}

# Configure tailscale serve
configure_serve() {
    echo ""
    echo "=== Configuring Tailscale Serve ==="
    
    for ext_port in "${!SERVE_PORTS[@]}"; do
        int_port="${SERVE_PORTS[$ext_port]}"
        echo "Setting up serve: $ext_port -> $int_port"
        tailscale serve --bg --http "$ext_port" "$int_port" || true
    done
    
    # Special spoolman service
    if systemctl is-active --quiet spoolman; then
        echo "Setting up spoolman service on 7912"
        tailscale serve --bg --service=svc:spoolman --http 7912 7912 || true
    fi
    
    echo -e "${GREEN}Serve configured${NC}"
}

# Configure tailscale funnel
configure_funnel() {
    echo ""
    echo "=== Configuring Tailscale Funnel ==="
    
    for ext_port in "${!FUNNEL_PORTS[@]}"; do
        int_port="${FUNNEL_PORTS[$ext_port]}"
        echo "Setting up funnel: $ext_port -> $int_port"
        tailscale funnel --bg --https "$ext_port" "$int_port" || true
    done
    
    echo -e "${GREEN}Funnel configured${NC}"
}

# Advertise services
advertise_services() {
    echo ""
    echo "=== Advertising Services ==="
    
    tailscale serve advertise "svc:$SERVE_ADVERTISE" || true
    tailscale serve advertise "svc:spoolman" || true
    
    echo -e "${GREEN}Services advertised${NC}"
}

# Main execution
main() {
    echo "Starting Tailscale Service Check for $HOST_TYPE"
    
    # Step 1: Wait for local services
    if ! wait_for_services; then
        echo -e "${RED}Local services not ready, aborting${NC}"
        exit 1
    fi
    
    # Step 2: Start tailscaled
    if ! start_tailscaled; then
        echo -e "${RED}Failed to start tailscaled, aborting${NC}"
        exit 1
    fi
    
    # Step 3: Configure serve
    configure_serve
    
    # Step 4: Configure funnel
    configure_funnel
    
    # Step 5: Advertise
    advertise_services
    
    echo ""
    echo -e "${GREEN}=== Tailscale setup complete for $HOST_TYPE ===${NC}"
    echo "Tailscale status:"
    tailscale status
}

# Run main
main "$@"
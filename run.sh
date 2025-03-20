#!/bin/bash

# Define color codes
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print formatted messages
print_step() {
    echo -e "${GREEN}[$1/$TOTAL_STEPS] $2${NC}"
}

# Main menu function
show_menu() {
    echo -e "\n${BLUE}=== T3RN EXECUTOR MANAGER ===${NC}"
    echo -e "${YELLOW}1. Install Executor${NC}"
    echo -e "${YELLOW}2. Exit${NC}"
    echo -e "${BLUE}=============================${NC}"
    read -p "$(echo -e ${YELLOW}"Select an option [1-2]: "${NC})" choice
    
    case $choice in
        1)
            install_executor
            ;;
        2)
            echo -e "${GREEN}Thank you for using T3rn Executor Manager.${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice. Please select 1-2.${NC}"
            show_menu
            ;;
    esac
}

# Function to install the executor
install_executor() {
    # Configuration
    TOTAL_STEPS=7

    # Ask for executor user
    read -p "$(echo -e ${YELLOW}"Enter the user name to run the executor (default: root): "${NC})" EXECUTOR_USER
    EXECUTOR_USER=${EXECUTOR_USER:-root}

    # Ask for private key (securely)
    echo -e "${YELLOW}Enter PRIVATE_KEY_LOCAL:${NC}"
    read -sp "" PRIVATE_KEY_LOCAL
    echo ""

    # Set directory paths
    INSTALL_DIR="/home/$EXECUTOR_USER/t3rn"
    SERVICE_FILE="/etc/systemd/system/t3rn-executor.service"
    ENV_FILE="/etc/t3rn-executor.env"

    # Step 1: Create installation directory
    print_step "1" "Creating installation directory..."
    mkdir -p "$INSTALL_DIR" && cd "$INSTALL_DIR"

    # Step 2: Get latest release version
    print_step "2" "Fetching the latest version..."
    TAG=$(curl -s https://api.github.com/repos/t3rn/executor-release/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
    echo -e "${GREEN}Latest version: $TAG${NC}"

    # Step 3: Download and extract release
    print_step "3" "Downloading and extracting release..."
    wget -q "https://github.com/t3rn/executor-release/releases/download/$TAG/executor-linux-$TAG.tar.gz"
    tar -xzf "executor-linux-$TAG.tar.gz"
    cd executor/executor/bin

    # Step 4: Create configuration file
    print_step "4" "Creating configuration file..."
    # Create environment file with RPC endpoints
    sudo bash -c "cat > $ENV_FILE" <<EOL
RPC_ENDPOINTS="{\"l2rn\": [\"https://b2n.rpc.caldera.xyz/http\"], \"arbt\": [\"https://arbitrum-sepolia.drpc.org\", \"https://sepolia-rollup.arbitrum.io/rpc\"], \"bast\": [\"https://base-sepolia-rpc.publicnode.com\", \"https://base-sepolia.drpc.org\"], \"opst\": [\"https://sepolia.optimism.io\", \"https://optimism-sepolia.drpc.org\"], \"unit\": [\"https://unichain-sepolia.drpc.org\", \"https://sepolia.unichain.org\"]}"
EOL

    # Step 5: Set proper permissions
    print_step "5" "Setting permissions..."
    sudo chown -R "$EXECUTOR_USER":"$EXECUTOR_USER" "$INSTALL_DIR"
    sudo chmod 600 "$ENV_FILE"

    # Step 6: Create systemd service file
    print_step "6" "Creating service file..."
    sudo bash -c "cat > $SERVICE_FILE" <<EOL
[Unit]
Description=t3rn Executor Service
After=network.target

[Service]
User=$EXECUTOR_USER
WorkingDirectory=$INSTALL_DIR/executor/executor/bin
ExecStart=$INSTALL_DIR/executor/executor/bin/executor
Restart=always
RestartSec=10
Environment=ENVIRONMENT=testnet
Environment=LOG_LEVEL=debug
Environment=LOG_PRETTY=false
Environment=EXECUTOR_PROCESS_BIDS_ENABLED=true
Environment=EXECUTOR_PROCESS_ORDERS_ENABLED=true
Environment=EXECUTOR_PROCESS_CLAIMS_ENABLED=true
Environment=EXECUTOR_MAX_L3_GAS_PRICE=100
Environment=PRIVATE_KEY_LOCAL=$PRIVATE_KEY_LOCAL
Environment=ENABLED_NETWORKS=arbitrum-sepolia,base-sepolia,optimism-sepolia,l2rn
EnvironmentFile=$ENV_FILE
Environment=EXECUTOR_PROCESS_PENDING_ORDERS_FROM_API=true

[Install]
WantedBy=multi-user.target
EOL

    # Step 7: Start service
    print_step "7" "Starting service..."
    sudo systemctl daemon-reload
    sudo systemctl enable t3rn-executor.service
    sudo systemctl start t3rn-executor.service

    # Installation complete
    echo -e "${GREEN}✅ Executor installed and running successfully!${NC}"
    
    # Ask if user wants to see logs
    read -p "$(echo -e ${YELLOW}"Show logs? (y/n): "${NC})" show_logs
    if [[ $show_logs == "y" || $show_logs == "Y" ]]; then
        echo -e "${YELLOW}Showing real-time logs... (Press Ctrl+C to exit)${NC}"
        sudo journalctl -u t3rn-executor.service -f --no-hostname -o cat
    else
        echo -e "${GREEN}To view logs, use the command: sudo journalctl -u t3rn-executor.service -f${NC}"
        sleep 2
        show_menu
    fi
}

# Start program
show_menu

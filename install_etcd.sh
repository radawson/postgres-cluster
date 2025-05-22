#!/bin/bash

# Validate and format node number
if [ -z "$1" ]; then
    echo "Error: Node number is required"
    echo "Usage: $0 <node-number> [ip-address]"
    echo "If no IP address is provided, the first non-loopback adapter will be used"
    exit 1
fi

# Convert input to integer and validate range
if ! [[ "$1" =~ ^[0-9]+$ ]]; then
    echo "Error: Node number must be a positive integer"
    exit 1
fi

if [ "$1" -gt 99 ]; then
    echo "Error: Node number must be between 1 and 99"
    exit 1
fi

# Zero-pad single digit numbers
NODE_NUMBER=$(printf "%02d" "$1")

# Handle IP address
if [ -n "$2" ]; then
    # Validate provided IP address format
    if ! [[ "$2" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "Error: Invalid IP address format"
        echo "Expected format: xxx.xxx.xxx.xxx"
        exit 1
    fi

    # Validate each octet is between 0 and 255
    IFS='.' read -r -a octets <<< "$2"
    for octet in "${octets[@]}"; do
        if [ "$octet" -lt 0 ] || [ "$octet" -gt 255 ]; then
            echo "Error: IP address octets must be between 0 and 255"
            exit 1
        fi
    done
    IP_ADDRESS=$2
else
    # Auto-detect first non-loopback IPv4 address
    IP_ADDRESS=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '^127\.' | head -n1)
    if [ -z "$IP_ADDRESS" ]; then
        echo "Error: Could not automatically detect IPv4 address"
        echo "Please provide an IP address as the second argument"
        exit 1
    fi
    echo "Using auto-detected IP address: ${IP_ADDRESS}"
fi

# Create etcd environment configuration
cat <<EOF | sudo tee /etc/etcd/etcd.env
# Node identity
ETCD_NAME="postgresql-${NODE_NUMBER}"
ETCD_DATA_DIR="/var/lib/etcd"

# Cluster configuration
ETCD_INITIAL_CLUSTER="postgresql-01=https://10.10.13.51:2380,postgresql-02=https://10.10.13.52:2380,postgresql-03=https://10.10.13.53:2380"
ETCD_INITIAL_CLUSTER_STATE="new"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"

# Peer (server-to-server) communication
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://${IP_ADDRESS}:2380"
ETCD_LISTEN_PEER_URLS="https://${IP_ADDRESS}:2380"

# Client communication
ETCD_LISTEN_CLIENT_URLS="https://${IP_ADDRESS}:2379,https://127.0.0.1:2379"
ETCD_ADVERTISE_CLIENT_URLS="https://${IP_ADDRESS}:2379,https://127.0.0.1:2379"

# Security configuration
ETCD_CLIENT_CERT_AUTH="true"
ETCD_TRUSTED_CA_FILE="/etc/etcd/ssl/ca.crt"
ETCD_CERT_FILE="/etc/etcd/ssl/etcd-node${NODE_NUMBER}.crt"
ETCD_KEY_FILE="/etc/etcd/ssl/etcd-node${NODE_NUMBER}.key"
ETCD_PEER_CLIENT_CERT_AUTH="true"
ETCD_PEER_TRUSTED_CA_FILE="/etc/etcd/ssl/ca.crt"
ETCD_PEER_CERT_FILE="/etc/etcd/ssl/etcd-node${NODE_NUMBER}.crt"
ETCD_PEER_KEY_FILE="/etc/etcd/ssl/etcd-node${NODE_NUMBER}.key"

# Enable debug logging
ETCD_LOG_LEVEL="debug"
EOF

# Create service file
cat << EOF | sudo tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd key-value store
Documentation=https://github.com/etcd-io/etcd
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
User=etcd
Group=etcd
WorkingDirectory=/var/lib/etcd
EnvironmentFile=/etc/etcd/etcd.env
ExecStart=/usr/local/bin/etcd
Restart=always
RestartSec=10s
LimitNOFILE=40000

[Install]
WantedBy=multi-user.target
EOF

# Create etcd data directory
sudo mkdir -p /var/lib/etcd 
sudo chown -R etcd:etcd /var/lib/etcd

# Update firewall settings
sudo ufw allow 2379/tcp comment 'etcd client communication'
sudo ufw allow 2380/tcp comment 'etcd server-to-server communication'

# Enable and start etcd service
sudo systemctl daemon-reload
sudo systemctl enable etcd
sudo systemctl restart etcd

# Wait for service to start
echo "Waiting for etcd service to start..."
sleep 5

# Check service status
sudo systemctl status etcd --no-pager --output=cat

# Display some helpful commands
echo ""
echo "To check cluster health using remote IP, use:"
echo "ETCDCTL_API=3 etcdctl --endpoints=https://${IP_ADDRESS}:2379 \\"
echo "  --cacert=/etc/etcd/ssl/ca.crt \\"
echo "  --cert=/etc/etcd/ssl/etcd-node${NODE_NUMBER}.crt \\"
echo "  --key=/etc/etcd/ssl/etcd-node${NODE_NUMBER}.key \\"
echo "  endpoint health"
echo ""
echo "Or using localhost:"
echo "ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \\"
echo "  --cacert=/etc/etcd/ssl/ca.crt \\"
echo "  --cert=/etc/etcd/ssl/etcd-node${NODE_NUMBER}.crt \\"
echo "  --key=/etc/etcd/ssl/etcd-node${NODE_NUMBER}.key \\"
echo "  endpoint health"
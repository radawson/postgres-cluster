#!/bin/bash

# Validate and format node number
if [ -z "$1" ]; then
    echo "Error: Node number is required"
    echo "Usage: $0 <node-number>"
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

# Create etcd SSL directory if it doesn't exist
sudo mkdir -p /etc/etcd/ssl

# Move certificates from temporary location to etcd SSL directory
sudo mv postgres-node${NODE_NUMBER}.crt /etc/etcd/ssl/etcd-node${NODE_NUMBER}.crt
sudo mv postgres-node${NODE_NUMBER}.key /etc/etcd/ssl/etcd-node${NODE_NUMBER}.key
sudo mv ca.crt /etc/etcd/ssl/

# Set etcd user as owner of the SSL directory and contents
sudo chown -R etcd:etcd /etc/etcd/ssl/

# Set secure permissions:
# - Private key should be read-only by etcd user (600)
# - Public certificates can be world-readable (644)
sudo chmod 600 /etc/etcd/ssl/etcd-node${NODE_NUMBER}.key
sudo chmod 644 /etc/etcd/ssl/etcd-node${NODE_NUMBER}.crt /etc/etcd/ssl/ca.crt
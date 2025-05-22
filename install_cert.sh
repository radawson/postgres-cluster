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

# Check if required files exist
for file in "postgres-node${NODE_NUMBER}.crt" "postgres-node${NODE_NUMBER}.key"; do
    if [ ! -f "$file" ]; then
        echo "Error: Required file $file not found in current directory"
        exit 1
    fi
done

# Create etcd SSL directory if it doesn't exist
sudo mkdir -p /etc/etcd/ssl

# Copy certificates to etcd SSL directory
sudo cp postgres-node${NODE_NUMBER}.crt /etc/etcd/ssl/etcd-node${NODE_NUMBER}.crt
sudo cp postgres-node${NODE_NUMBER}.key /etc/etcd/ssl/etcd-node${NODE_NUMBER}.key
sudo cp ca.crt /etc/etcd/ssl/

# Set etcd user as owner of the SSL directory and contents
sudo chown -R etcd:etcd /etc/etcd/ssl/

# Set secure permissions:
# - Private key should be read-only by etcd user (600)
# - Public certificates can be world-readable (644)
sudo chmod 600 /etc/etcd/ssl/etcd-node${NODE_NUMBER}.key
sudo chmod 644 /etc/etcd/ssl/etcd-node${NODE_NUMBER}.crt /etc/etcd/ssl/ca.crt

# Verify files were copied correctly
echo "Verifying installed certificates:"
for file in "/etc/etcd/ssl/etcd-node${NODE_NUMBER}.crt" "/etc/etcd/ssl/etcd-node${NODE_NUMBER}.key" "/etc/etcd/ssl/ca.crt"; do
    if [ -f "$file" ]; then
        echo "✓ $file"
        ls -l "$file"
    else
        echo "✗ $file not found!"
        exit 1
    fi
done
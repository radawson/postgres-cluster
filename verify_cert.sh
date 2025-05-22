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

# Function to display certificate details
show_cert_details() {
    local cert_file=$1
    local cert_name=$2
    
    echo "Certificate details for ${cert_name}:"
    echo "==================="
    
    # Display Subject Alternative Names (DNS and IP addresses)
    echo "Subject Alternative Names:"
    openssl x509 -in "$cert_file" -text -noout | grep -A2 "Subject Alternative Name"
    echo ""
    
    # Display Key Usage restrictions
    echo "Key Usage:"
    openssl x509 -in "$cert_file" -text -noout | grep -A2 "Key Usage"
    echo ""
    
    # Display Subject Distinguished Name
    echo "Subject Name:"
    openssl x509 -in "$cert_file" -text -noout | grep "Subject:"
    echo ""
    
    # Display certificate validity period
    echo "Validity Period:"
    openssl x509 -in "$cert_file" -text -noout | grep -A2 "Validity"
    echo ""
}

# Check original certificate
ORIG_CERT="postgres-node${NODE_NUMBER}.crt"
if [ -f "$ORIG_CERT" ]; then
    show_cert_details "$ORIG_CERT" "Original Certificate"
else
    echo "Warning: Original certificate $ORIG_CERT not found"
fi

# Check installed certificate
INSTALLED_CERT="/etc/etcd/ssl/etcd-node${NODE_NUMBER}.crt"
if [ -f "$INSTALLED_CERT" ]; then
    show_cert_details "$INSTALLED_CERT" "Installed Certificate"
else
    echo "Warning: Installed certificate $INSTALLED_CERT not found"
fi

# Verify certificate chain
if [ -f "/etc/etcd/ssl/ca.crt" ]; then
    echo "Verifying certificate chain:"
    openssl verify -CAfile /etc/etcd/ssl/ca.crt "$INSTALLED_CERT"
else
    echo "Warning: CA certificate not found at /etc/etcd/ssl/ca.crt"
fi 
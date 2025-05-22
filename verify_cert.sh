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

# Check if the signed certificate file exists
if [ ! -f "postgres-node${NODE_NUMBER}.crt" ]; then
    echo "Error: Certificate file postgres-node${NODE_NUMBER}.crt not found!"
    echo "Please ensure you've saved the CA's response as postgres-node${NODE_NUMBER}.crt"
    exit 1
fi

# Display header for certificate information
echo "Certificate details:"
echo "==================="
echo ""

# Display Subject Alternative Names (DNS and IP addresses)
echo "Subject Alternative Names:"
openssl x509 -in postgres-node${NODE_NUMBER}.crt -text -noout | grep -A2 "Subject Alternative Name"
echo ""

# Display Key Usage restrictions
echo "Key Usage:"
openssl x509 -in postgres-node${NODE_NUMBER}.crt -text -noout | grep -A2 "Key Usage"
echo ""

# Display Subject Distinguished Name
echo "Subject Name:"
openssl x509 -in postgres-node${NODE_NUMBER}.crt -text -noout | grep "Subject:"
echo ""

# Display certificate validity period
echo "Validity Period:"
openssl x509 -in postgres-node${NODE_NUMBER}.crt -text -noout | grep -A2 "Validity" 
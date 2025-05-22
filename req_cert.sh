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

# Generate a 2048-bit RSA private key for the PostgreSQL node
openssl genrsa -out postgres-node${NODE_NUMBER}.key 4096

# Create OpenSSL configuration file with certificate requirements
# This includes:
#  - Distinguished name requirements
#  - Key usage restrictions for etcd peer and client authentication
#  - Subject Alternative Names (DNS and IP)
cat > temp.cnf <<EOF
[ req ]
distinguished_name = req_distinguished_name
req_extensions = v3_req
[ req_distinguished_name ]

[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names
[ alt_names ]
DNS.1 = postgres-node${NODE_NUMBER}.intranet.partridgexing.org
DNS.2 = postgres-node${NODE_NUMBER}
DNS.3 = pg${NODE_NUMBER}
IP.1 = ${IP_ADDRESS}
IP.2 = 127.0.0.1
EOF

# Generate Certificate Signing Request (CSR) using the config and private key
openssl req -new -key postgres-node${NODE_NUMBER}.key -out postgres-node${NODE_NUMBER}.csr \
  -subj "/C=US/ST=Connecticut/L=Hamden/O=ClockWorX/OU=Intranet/CN=postgres-node${NODE_NUMBER}.intranet.partridgexing.org" \
  -config temp.cnf

# Clean up the temporary config file
rm temp.cnf

# Display information about the generated files
echo "Certificate signing request has been generated:"
echo "  - Private key: postgres-node${NODE_NUMBER}.key"
echo "  - CSR file: postgres-node${NODE_NUMBER}.csr"
echo ""
echo "Please submit the CSR to your certificate authority and save the response as:"
echo "  postgres-node${NODE_NUMBER}.crt"
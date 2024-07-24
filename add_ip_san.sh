#!/bin/bash
# this shell script will remove(keep backup) of initial (old) kubelet certificate which olny has node #hostname as the SAN and create new certifcates for the kubelet which has node ip and hostname as the SAN .
# Variables (replace these with your actual values)
NODE_HOSTNAME=$(hostname)
NODE_IP=$(hostname -i)
KUBELET_PKI_DIR="/var/lib/kubelet/pki"
CA_CERT="/home/ec2-user/master_ca/ca.crt"
CA_KEY="/home/ec2-user/master_ca/ca.key"
CSR_CONF="csr.conf"

# Create the CSR configuration file
cat <<EOF > $CSR_CONF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
prompt = no

[req_distinguished_name]
CN = $NODE_HOSTNAME

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $NODE_HOSTNAME
IP.1 = $NODE_IP
EOF

# Stop the kubelet
sudo systemctl stop kubelet

# Backup existing certificates
sudo mv $KUBELET_PKI_DIR/kubelet.crt $KUBELET_PKI_DIR/kubelet.crt.bak
sudo mv $KUBELET_PKI_DIR/kubelet.key $KUBELET_PKI_DIR/kubelet.key.bak

# Generate a new private key and CSR
openssl genrsa -out kubelet.key 2048
openssl req -new -key kubelet.key -out kubelet.csr -config $CSR_CONF

# Sign the CSR using the Kubernetes CA
openssl x509 -req -in kubelet.csr -CA $CA_CERT -CAkey $CA_KEY -CAcreateserial -out kubelet.crt -days 365 -extensions v3_req -extfile $CSR_CONF

# Move the new certificates to the kubelet's pki directory
sudo mv kubelet.crt $KUBELET_PKI_DIR/kubelet.crt
sudo mv kubelet.key $KUBELET_PKI_DIR/kubelet.key

# Restart the kubelet
sudo systemctl daemon-reload
sudo systemctl restart kubelet

# Clean up
rm -f kubelet.csr
rm -f $CSR_CONF

# Verify the new certificate
openssl x509 -noout -text -in $KUBELET_PKI_DIR/kubelet.crt

# Remove the Cluster CA_CERT and CA_KEY
sudo rm -f $CA_CERT
sudo rm -f $CA_KEY
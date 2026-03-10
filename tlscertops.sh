#!/bin/bash
set -e
echo ""
echo " TLS certificate generation for Mosquitto broker and client"
echo ""

mkdir -p tlscertsops
cd tlscertsops
    
# Request passphrase once upfront
read -rsp "Enter pass phrase for CA key: " PASSPHRASE && echo

# ── Directory setup ──────────────────────────────────────────────
mkdir -p mosquitto
mkdir -p myca/{safe,certs}

# ── CA setup ─────────────────────────────────────────────────────
cd myca

cat > ca.cnf << EOF
# OpenSSL CA configuration file
[ ca ]
default_ca = CA_default

[ CA_default ]
default_days = 365
database = index.txt
serial = serial.txt
default_md = sha256
copy_extensions = copy
unique_subject = no

# Used to create the CA certificate.
[ req ]
prompt=no
distinguished_name = distinguished_name
x509_extensions = extensions

[ distinguished_name ]
countryName = AT
stateOrProvinceName = Vienna
organizationName = MIO-2
commonName = MIO-2

[ extensions ]
keyUsage = critical,digitalSignature,nonRepudiation,keyEncipherment,keyCertSign
basicConstraints = critical,CA:true,pathlen:1

# Common policy for nodes and users.
[ signing_policy ]
organizationName = supplied
commonName = optional

# Used to sign node certificates.
[ signing_node_req ]
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = serverAuth

# Used to sign client certificates.
[ signing_client_req ]
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = clientAuth
EOF

touch index.txt
echo '01' > serial.txt

# Generate CA key (passphrase-protected) and self-signed certificate
openssl genrsa -des3 -passout pass:"$PASSPHRASE" -verbose -out safe/ca.key 2048
chmod 400 safe/ca.key
openssl req -new -x509 -config ca.cnf -key safe/ca.key -passin pass:"$PASSPHRASE" -out certs/ca.crt -days 3650 -batch

# ── Mosquitto broker certificate ──────────────────────────────────
cd ../mosquitto

openssl genrsa -verbose -out mosquitto.key 2048
chmod 400 mosquitto.key

cat > mosquitto.cnf << EOF
[ req ]
prompt=no
distinguished_name = distinguished_name
req_extensions = extensions

[ distinguished_name ]
countryName = AT
stateOrProvinceName = Vienna
organizationName = MIO-2
commonName = iotgw.local

[ extensions ]
subjectAltName = @alt_names

[alt_names]
DNS.1 = iotgw.local
DNS.2 = iotgw
DNS.3 = mosquitto
EOF

openssl req -new -config mosquitto.cnf -key mosquitto.key -out mosquitto.csr -batch

cd ../myca
openssl ca -config ca.cnf -keyfile safe/ca.key -cert certs/ca.crt -policy signing_policy \
  -extensions signing_node_req -passin pass:"$PASSPHRASE" \
  -out certs/mosquitto.crt -outdir certs/ -in ../mosquitto/mosquitto.csr -notext -days 3650 -batch

cp certs/mosquitto.crt ../mosquitto/

# ── Client certificate ────────────────────────────────────────────
cd ..
mkdir -p client
cd client

openssl genrsa -verbose -out client.key 2048
chmod 400 client.key

cat > client.cnf << EOF
[ req ]
prompt=no
distinguished_name = distinguished_name

[ distinguished_name ]
countryName = AT
stateOrProvinceName = Vienna
localityName = Vienna
organizationName = MIO-2
commonName = client
EOF

openssl req -new -config client.cnf -key client.key -out client.csr -batch

cd ../myca
openssl ca -config ca.cnf -keyfile safe/ca.key -cert certs/ca.crt -policy signing_policy \
  -extensions signing_client_req -passin pass:"$PASSPHRASE" \
  -out certs/client.crt -outdir certs/ -in ../client/client.csr -notext -batch

echo ""
echo "Done. Certificates generated:"
echo "  CA cert:         myca/certs/ca.crt"
echo "  Mosquitto cert:  myca/certs/mosquitto.crt  +  mosquitto/mosquitto.crt"
echo "  Client cert:     myca/certs/client.crt"
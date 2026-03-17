#!/bin/bash
set -euo pipefail

#!/bin/bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKI_DIR="$BASE_DIR/tlscertsops"
CA_DIR="$PKI_DIR/myca"

mkdir -p "$PKI_DIR"

read -rsp "Enter CA passphrase: " PASSPHRASE
echo

# ---------- CA Bootstrap ----------
if [[ ! -f "$CA_DIR/ca.cnf" ]]; then
  echo "CA not found. Initialising new Certificate Authority..."

  mkdir -p "$CA_DIR"/{safe,certs}

  cat > "$CA_DIR/ca.cnf" <<EOF
[ ca ]
default_ca = CA_default

[ CA_default ]
default_days = 365
database = index.txt
serial = serial.txt
default_md = sha256
copy_extensions = copy
unique_subject = no

[ req ]
prompt=no
distinguished_name = distinguished_name
x509_extensions = extensions

[ distinguished_name ]
countryName = AT
stateOrProvinceName = Vienna
organizationName = MIO-2
commonName = MIO-2-Root-CA

[ extensions ]
keyUsage = critical,digitalSignature,nonRepudiation,keyEncipherment,keyCertSign
basicConstraints = critical,CA:true,pathlen:1

[ signing_policy ]
organizationName = supplied
commonName = optional

[ signing_node_req ]
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = serverAuth

[ signing_client_req ]
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = clientAuth
EOF

  touch "$CA_DIR/index.txt"
  echo '01' > "$CA_DIR/serial.txt"

  echo "Generating CA private key..."
  openssl genrsa -des3 \
    -passout pass:"$PASSPHRASE" \
    -out "$CA_DIR/safe/ca.key" 4096

  chmod 400 "$CA_DIR/safe/ca.key"

  echo "Generating CA certificate..."

  openssl req -new -x509 \
    -config "$CA_DIR/ca.cnf" \
    -key "$CA_DIR/safe/ca.key" \
    -passin pass:"$PASSPHRASE" \
    -out "$CA_DIR/certs/ca.crt" \
    -days 3650 \
    -batch

  echo "CA successfully created"
fi


# ---------- Validate CA ----------
if [[ ! -f "$CA_DIR/ca.cnf" ]]; then
  echo "ERROR: Missing CA config: $CA_DIR/ca.cnf"
  exit 1
fi

if [[ ! -f "$CA_DIR/safe/ca.key" ]]; then
  echo "ERROR: Missing CA private key"
  exit 1
fi

if [[ ! -f "$CA_DIR/certs/ca.crt" ]]; then
  echo "ERROR: Missing CA certificate"
  exit 1
fi

# ---------- CNF generator ----------
create_config() {

NAME=$1
TYPE=$2
DIR="$PKI_DIR/$NAME"

mkdir -p "$DIR"

if [[ "$TYPE" == "server" ]]; then

cat > "$DIR/$NAME.cnf" <<EOF
[ req ]
prompt = no
distinguished_name = dn
req_extensions = ext

[ dn ]
countryName = AT
stateOrProvinceName = Vienna
organizationName = MIO-2
commonName = $NAME

[ ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = $NAME
DNS.2 = localhost
DNS.3 = iotgw
EOF

else

cat > "$DIR/$NAME.cnf" <<EOF
[ req ]
prompt = no
distinguished_name = dn

[ dn ]
countryName = AT
stateOrProvinceName = Vienna
organizationName = MIO-2
commonName = $NAME
EOF

fi
}

# ---------- Certificate generator ----------
generate_cert() {

NAME=$1
EXT=$2
DIR="$PKI_DIR/$NAME"

echo "Generating certificate: $NAME"

openssl genrsa -out "$DIR/$NAME.key" 2048
chmod 400 "$DIR/$NAME.key"

openssl req \
  -new \
  -config "$DIR/$NAME.cnf" \
  -key "$DIR/$NAME.key" \
  -out "$DIR/$NAME.csr" \
  -batch

openssl ca \
  -config "$CA_DIR/ca.cnf" \
  -keyfile "$CA_DIR/safe/ca.key" \
  -cert "$CA_DIR/certs/ca.crt" \
  -policy signing_policy \
  -extensions "$EXT" \
  -passin pass:"$PASSPHRASE" \
  -out "$CA_DIR/certs/$NAME.crt" \
  -in "$DIR/$NAME.csr" \
  -notext \
  -days 3650 \
  -batch

cp "$CA_DIR/certs/$NAME.crt" "$DIR/"
cp "$CA_DIR/certs/ca.crt" "$DIR/"

echo "✔ $NAME certificate created"
}

# ---------- Services ----------
create_config mosquitto server
create_config influxdb server
create_config client client
create_config ble client
create_config backend client

generate_cert mosquitto signing_node_req
generate_cert influxdb signing_node_req
generate_cert client signing_client_req
generate_cert ble signing_client_req
generate_cert backend signing_client_req

echo ""
echo "--------------------------------------"
echo "Certificates successfully generated"
echo "--------------------------------------"
echo ""
echo "Mosquitto: $PKI_DIR/mosquitto"
echo "InfluxDB:  $PKI_DIR/influxdb"
echo "Client:    $PKI_DIR/client"
echo "BLE:       $PKI_DIR/ble"
echo "Backend:   $PKI_DIR/backend"
echo ""


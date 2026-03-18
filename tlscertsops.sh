#!/bin/bash
# tlscertsops.sh - TLS certificate generation for Mosquitto broker and clients

set -e

echo ""
echo " TLS certificate generation for Mosquitto broker and clients"
echo ""

# ── Clean previous lab artifacts if they exist ───────────────────

echo "Cleaning previous TLS artifacts..."

# ── Clean previous lab artifacts if they exist ───────────────────

echo "Cleaning previous TLS artifacts..."

for dir in \
    ./ble_engine/certs \
    ./client \
    ./iot_storage \
    ./lab-storage \
    ./mosquitto \
    ./backend \
    ./tlscertsops
do
    if [ -d "$dir" ]; then
        echo "Removing $dir"
        sudo rm -rf "$dir"
    fi
done

echo "Cleanup completed."
echo ""

mkdir -p tlscertsops
mkdir -p iot_storage/mosquitto-data-storage # I am reviewing these 2 lines later
mkdir -p iot_storage/mosquitto-log-storage #


mkdir -p iot_storage/influxdb-storage
mkdir -p iot_storage/nodered-storage
sudo chown -R 1000:1000 iot_storage/nodered-storage
chmod -R 775 iot_storage/nodered-storage



cd tlscertsops

# Request passphrase once
#read -rsp "Enter pass phrase for CA key: " PASSPHRASE && echo
PASSPHRASE=testpassphrase
# ── Directory structure ─────────────────────────────────────────

mkdir -p mosquitto
mkdir -p client
mkdir -p ble
mkdir -p backend
mkdir -p myca/{safe,certs}

# ── CA setup ───────────────────────────────────────────────────

echo ""
echo "Setting up Certificate Authority..."

cd myca

cat > ca.cnf << EOF
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

touch index.txt
echo '01' > serial.txt

echo "Generating CA private key..."

openssl genrsa -des3 \
  -passout pass:"$PASSPHRASE" \
  -out safe/ca.key 2048

chmod 400 safe/ca.key

echo "Generating CA certificate..."

openssl req -new -x509 \
  -config ca.cnf \
  -key safe/ca.key \
  -passin pass:"$PASSPHRASE" \
  -out certs/ca.crt \
  -days 3650 \
  -batch

# ── Mosquitto broker certificate ───────────────────────────────

echo ""
echo "Generating Mosquitto broker certificate..."

cd ../mosquitto

openssl genrsa -out mosquitto.key 2048
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
commonName = mosquitto

[ extensions ]
subjectAltName = @alt_names

[alt_names]
DNS.1 = mosquitto
DNS.2 = localhost
DNS.3 = iotgw
EOF

openssl req -new \
  -config mosquitto.cnf \
  -key mosquitto.key \
  -out mosquitto.csr \
  -batch

cd ../myca

openssl ca \
  -config ca.cnf \
  -keyfile safe/ca.key \
  -cert certs/ca.crt \
  -policy signing_policy \
  -extensions signing_node_req \
  -passin pass:"$PASSPHRASE" \
  -out certs/mosquitto.crt \
  -outdir certs/ \
  -in ../mosquitto/mosquitto.csr \
  -notext \
  -days 3650 \
  -batch

cp certs/mosquitto.crt ../mosquitto/
cp certs/ca.crt ../mosquitto/

# ── MQTT client certificate ────────────────────────────────────

echo ""
echo "Generating MQTT client certificate..."

cd ../client

openssl genrsa -out client.key 2048
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
commonName = mqtt-client
EOF

openssl req -new \
  -config client.cnf \
  -key client.key \
  -out client.csr \
  -batch

cd ../myca

openssl ca \
  -config ca.cnf \
  -keyfile safe/ca.key \
  -cert certs/ca.crt \
  -policy signing_policy \
  -extensions signing_client_req \
  -passin pass:"$PASSPHRASE" \
  -out certs/client.crt \
  -outdir certs/ \
  -in ../client/client.csr \
  -notext \
  -days 3650 \
  -batch

cp certs/client.crt ../client/
cp certs/ca.crt ../client/

# ── BLE publisher certificate ──────────────────────────────────

echo ""
echo "Generating BLE publisher certificate..."

cd ../ble

openssl genrsa -out ble.key 2048
chmod 400 ble.key

cat > ble.cnf << EOF
[ req ]
prompt=no
distinguished_name = distinguished_name

[ distinguished_name ]
countryName = AT
stateOrProvinceName = Vienna
localityName = Vienna
organizationName = MIO-2
commonName = ble-publisher
EOF

openssl req -new \
  -config ble.cnf \
  -key ble.key \
  -out ble.csr \
  -batch

cd ../myca

openssl ca \
  -config ca.cnf \
  -keyfile safe/ca.key \
  -cert certs/ca.crt \
  -policy signing_policy \
  -extensions signing_client_req \
  -passin pass:"$PASSPHRASE" \
  -out certs/ble.crt \
  -outdir certs/ \
  -in ../ble/ble.csr \
  -notext \
  -days 3650 \
  -batch
pwd
cp certs/ble.crt ../ble/
cp certs/ca.crt ../ble/

# ── Backend certificate ────────────────────────────────────
pwd
echo ""
echo "Generating Backend certificate..."

cd ../backend/

openssl genrsa -out backend.key 2048
chmod 400 backend.key

cat > backend.cnf << EOF
[ req ]
prompt=no
distinguished_name = distinguished_name

[ distinguished_name ]
countryName = AT
stateOrProvinceName = Vienna
localityName = Vienna
organizationName = MIO-2
commonName = backend-database
EOF

openssl req -new \
  -config backend.cnf \
  -key backend.key \
  -out backend.csr \
  -batch
pwd
cd ../myca
pwd
openssl ca \
  -config ca.cnf \
  -keyfile safe/ca.key \
  -cert certs/ca.crt \
  -policy signing_policy \
  -extensions signing_client_req \
  -passin pass:"$PASSPHRASE" \
  -out certs/backend.crt \
  -outdir certs/ \
  -in ../backend/backend.csr \
  -notext \
  -days 3650 \
  -batch

cp certs/backend.crt ../backend/
cp certs/ca.crt ../backend/
# ── Summary ─────────────────────────────────────────────────────

echo ""
echo "--------------------------------------------------"
echo " TLS certificates successfully generated"
echo "--------------------------------------------------"
echo ""
echo "CA:"
echo "  myca/certs/ca.crt"
echo ""
echo "Mosquitto broker:"
echo "  mosquitto/mosquitto.crt"
echo "  mosquitto/mosquitto.key"
echo ""
echo "MQTT Client:"
echo "  client/client.crt"
echo "  client/client.key"
echo ""
echo "BLE Publisher:"
echo "  ble/ble.crt"
echo "  ble/ble.key"
echo ""
echo "Node-red :"
echo "  backend/ble.crt"
echo "  backend/ble.key"
echo ""
echo "Ready for container builds."
echo ""
echo ""
echo " Run: ./containersmgt.sh    "
echo ""


cd ../../

./containersmgt.sh 
#!/bin/bash

source ~/.env.sh
cd ${HOME_DIR}

cat > ./${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}.cnf <<-EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[ dn ]
C=DE
ST=Hessen
L=Taunusstein
O=Karsten Bott
OU=DEMO
CN = ${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = *.sys.${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}
DNS.2 = *.login.sys.${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}
DNS.3 = *.uaa.sys.${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}
DNS.4 = *.apps.${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}
EOF

openssl req -x509 \
  -newkey rsa:2048 \
  -nodes \
  -keyout ${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}.key \
  -out ${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}.cert \
  -config ./${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}.cnf
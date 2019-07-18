#!/bin/bash
tlsCert="$(cat /home/bottkars/.acme.sh/pksazure.labbuildr.com/pksazure.labbuildr.com.cer | base64 -w 0)"
tlsKey="$(cat /home/bottkars/.acme.sh/pksazure.labbuildr.com/pksazure.labbuildr.com.key | base64 -w 0)"

cat << EOF | kubectl create -f -
---
apiVersion: v1
kind: Secret
metadata:
  name: build-service-certificate
  namespace: default
data:
  tls.crt: $tlsCert
  tls.key: $tlsKey
type: kubernetes.io/tls
EOF

duffle relocate -f /datadisks/disk1/build-service/0.0.1/bundle.json -m /tmp/relocated.json -p harbor.pksazure.labbuildr.com/build-service



duffle install my-build-service -c /tmp/credentials.yml  \
    --set domain=build-service.${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME} \
    --set kubernetes_env=k8s1 \
    --set docker_registry=harbor.${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME} \
    --set registry_username=admin \
    --set registry_password=${PIVNET_UAA_TOKEN} \
    --set uaa_url=api.${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}:8443 \
    -f /datadisks/disk1/build-service/0.0.1/bundle.json \
    -m /tmp/relocated.json  

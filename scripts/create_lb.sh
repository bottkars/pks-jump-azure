#!/usr/bin/env bash
source ~/.env.sh

CLUSTER=k8s1
az login --service-principal \
  --username ${AZURE_CLIENT_ID} \
  --password ${AZURE_CLIENT_SECRET} \
  --tenant ${AZURE_TENANT_ID}


az network lb create \
--resource-group ${ENV_NAME} \
--name ${CLUSTER}_lb \
--sku standard
--public-ip-address ${CLUSTER}_ip \
--frontend-ip-name ${CLUSTER}_fe \
--backend-pool-name ${CLUSTER}_be      

az network lb probe create \
--resource-group myResourceGroupSLB \
--lb-name myLoadBalancer \
--name myHealthProbe \
--protocol tcp \
--port 8443

az network lb rule create \
--resource-group ${ENV_NAME} \
--lb-name ${CLUSTER}_lb \
--name rule_8443 \
--protocol tcp \
--frontend-port any \
--backend-port 8443 \
--frontend-ip-name ${CLUSTER}_fe \
--backend-pool-name ${CLUSTER}_fbe \
--probe-name myHealthProbe  
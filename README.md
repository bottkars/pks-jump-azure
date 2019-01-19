# pks-jump-azure

<img src="https://docs.pivotal.io/images/pks.png" width="100"><img src="https://upload.wikimedia.org/wikipedia/commons/thumb/f/f1/Heart_coraz%C3%B3n.svg/800px-Heart_coraz%C3%B3n.svg.png" width="100">
<img src="https://docs.pivotal.io/images/icon_microsoft_azure@2x.png" width="100">

pks-jump-azure creates an ubuntu based jumpbox to auto-deploy Pivotal PKS (1.3 and above) on azure.  
it is based on an  [azure rm deployment template](./azuredeploy.json).  
<img src="https://user-images.githubusercontent.com/8255007/51332226-9e42fa80-1a7b-11e9-97ec-c91de80ace1c.png" width="400">  

*Cloning or downloading the repo is not required, as the arm automation takes care for all scripts* 

It will pave the infrastructure using Pivotal [terraforming-azure](https://github.com/pivotal-cf/terraforming-azure).  
Pivotal Operations Manager will be installed and configured using Pivotal [om cli](https://github.com/pivotal-cf/om).  
Optionally, PKS will be deployed using [om cli](https://github.com/pivotal-cf/om).  
For that, the Tile and required Stemcell is downloaded automatically.
## features

- automated opsman deployment and configuration
- pks infrastructure paving
- autopilot for deploying pks
- certificate generation using selfsigned or let´s encrypt [certificates](#certificates)
- dns registration of api loadbalancer ip
- network peering from jumphost to pks networks
- installation of cf-uaac, bosh cli
- dns configuration and check
- creation of public lb and dns a records for k8s clusters
- script for additional k8s clusters
- load balancer rules for uaa and api access

## requirements

- service principal needs to have owner rights on subscription in order to create custom roles and Managed Identities
- a [pivotal network account ( pivnet )](network.pivotal.io) and a UAA access token

## usage  

create an .env file using the .env.example  
see [parameters and variables](#parameters-and-variables) for details.  

source the env file  
```bash
source .env
```

## create a ssh keypair for the admin user ( if not already done )

```bash
ssh-keygen -t rsa -f ~/${JUMPBOX_NAME} -C ${ADMIN_USERNAME}
```

## start the deployment

there are multiple deployment options, using az cli, powershell, from variables/parameters or from parameter file
use  
[deployment using default parameters](#using-default-parameters)
or  
[deployment using customized parameters](#using-customized-parameters)  

Monitor your Deployment using [debugging section](#debugging-monitoring)

the deployment might pause after opsmanager deployment, if your  opsmanager  fqdn is not resolvable  
the log file will, at this stage, show the Azure Name Servers that need to be added to your DNS NS Record  

![image](https://user-images.githubusercontent.com/8255007/51382000-ed3d6e00-1b15-11e9-8318-04c9f0993a1d.png)  
once fixed, the deployment will continue.

[getting started after deployment](./initial_tasks.md)

### using default parameters

deployment using the default parameters only passes a minimum required parameters to the az command. all other values are set to their default.

```bash
az group create --name ${JUMPBOX_RG} --location ${AZURE_REGION}
az group deployment create --resource-group ${JUMPBOX_RG} \
    --template-uri https://raw.githubusercontent.com/bottkars/pks-jump-azure/master/azuredeploy.json \
    --parameters \
    sshKeyData="$(cat ~/${JUMPBOX_NAME}.pub)" \
    dnsLabelPrefix=${JUMPBOX_NAME} \
    clientSecret=${AZURE_CLIENT_SECRET} \
    clientID=${AZURE_CLIENT_ID} \
    tenantID=${AZURE_TENANT_ID} \
    subscriptionID=${AZURE_SUBSCRIPTION_ID} \
    pivnetToken=${PIVNET_UAA_TOKEN} \
    envShortName=${ENV_SHORT_NAME} \
    pksDomainName=${PKS_DOMAIN_NAME} \
    pksSubdomainName=${PKS_SUBDOMAIN_NAME} \
```

### using customized parameters

installation using customized parameter set´s all required parameters from variables in your .env file

```bash
az group create --name ${JUMPBOX_RG} --location ${AZURE_REGION}
az group deployment create --resource-group ${JUMPBOX_RG} \
    --template-uri https://raw.githubusercontent.com/bottkars/pks-jump-azure/master/azuredeploy.json \
    --parameters \
    adminUsername=${ADMIN_USERNAME} \
    sshKeyData="$(cat ~/${JUMPBOX_NAME}.pub)" \
    dnsLabelPrefix=${JUMPBOX_NAME} \
    clientSecret=${AZURE_CLIENT_SECRET} \
    clientID=${AZURE_CLIENT_ID} \
    tenantID=${AZURE_TENANT_ID} \
    subscriptionID=${AZURE_SUBSCRIPTION_ID} \
    pivnetToken=${PIVNET_UAA_TOKEN} \
    envName=${ENV_NAME} \
    envShortName=${ENV_SHORT_NAME} \
    opsmanImage=${OPS_MANAGER_IMAGE} \
    pksDomainName=${PKS_DOMAIN_NAME} \
    pksSubdomainName=${PKS_SUBDOMAIN_NAME} \
    opsmanUsername=${PKS_OPSMAN_USERNAME} \
    notificationsEmail=${PKS_NOTIFICATIONS_EMAIL} \
    pksAutopilot=${PKS_AUTOPILOT} \
    pksVersion=${PKS_VERSION} \
    net16bitmask=${NET_16_BIT_MASK} \
    useSelfCerts=${USE_SELF_CERTS} \
    _artifactsLocation=${ARTIFACTS_LOCATION} \
    vmSize=${VMSIZE}
```

## using a parameter file

tbd

## parameters and variables

 variable  | parameter  | default value  | mandatory | description  
--:|---|---|---|---
 IAAS  |   |   |   |
 JUMPBOX_RG  |   |   | no, only to create RG/ Deployment  |
 JUMPBOX_NAME  |   |   | yes  |
 ADMIN_USERNAME  |   | ubuntu  | no  |
 AZURE_CLIENT_ID  |   |   |  yes |
 AZURE_CLIENT_SECRET |   |   | yes  |
 AZURE_REGION  |   | westeurope  | no  |
 AZURE_SUBSCRIPTION_ID  |   |   | yes  |
 AZURE_TENANT_ID   |   |   | yes  |
 PIVNET_UAA_TOKEN  |   |   | yes  | will also be password for OpsManager and k8sadmin
 ENV_NAME  |   | pks  | no  |
 ENV_SHORT_NAME  |   |   |yes |
 OPS_MANAGER_IMAGE  |opsManImage   | ops-manager-2.4-build.142.vhd | no  |
 PKS_DOMAIN_NAME  |   |   | yes  |
 PKS_SUBDOMAIN_NAME  |   |   | yes  |
 PKS_VERSION  |   |1.3.0 |no|
 PKS_OPSMAN_USERNAME  |   | opsman  | no  |
 PKS_NOTIFICATIONS_EMAIL  |   | user@example.com  | no  | will also be used as k8sadmin email field
 PKS_AUTOPILOT  |   |TRUE   |no   |
 NET_16_BIT_MASK  |   |   | no  |
 USE_SELF_CERTS  |   | true  | no  |
   | opsmanImageRegion  | westeurope  | yes  |opsmanager image region, westus, easus, westeurope or southeasasia

## debugging/ monitoring

watching the JUMPHost resource group creation  

```bash
watch az resource list --output table --resource-group ${JUMPBOX_RG}
```

watching the pks resource group creation  

```bash
watch az resource list --output table --resource-group ${ENV_NAME}
```

ssh into the Jumpbox  

```bash
 ssh -i ~/${JUMPBOX_NAME} ubuntu@${JUMPBOX_NAME}.${AZURE_REGION}.cloudapp.azure.com
```

tail the installation log  

```bash
tail -f ~/install.log
```

## ssh into the opsmanager vm

from the jumpbox, you can  

```bash
source .env.sh
ssh -i opsman ubuntu@${PKS_OPSMAN_FQDN}

bosh alias-env pks -e 10.0.8.11 --ca-cert /var/tempest/workspaces/default/root_ca_certificate

```

## cleanup

```bash
az group delete --name ${JUMPBOX_RG} --yes
az group delete --name ${ENV_NAME} --yes
ssh-keygen -R "${JUMPBOX_NAME}.${AZURE_REGION}.cloudapp.azure.com"
```

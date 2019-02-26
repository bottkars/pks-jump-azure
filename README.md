# pks-jump-azure

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fbottkars%2Fpks-jump-azure%2Fmaster%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>
<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Fbottkars%2Fpks-jump-azure%2Fmaster%2Fazuredeploy.json" target="_blank">
    <img src="http://armviz.io/visualizebutton.png"/>
</a>

<img src="https://docs.pivotal.io/images/pks.png" width="100"><img src="https://upload.wikimedia.org/wikipedia/commons/thumb/f/f1/Heart_coraz%C3%B3n.svg/800px-Heart_coraz%C3%B3n.svg.png" width="100">
<img src="https://docs.pivotal.io/images/icon_microsoft_azure@2x.png" width="100">

pks-jump-azure creates an ubuntu based jumpbox to auto-deploy Pivotal PKS (1.3 and above) on azure.  
it is based on an  [azure rm deployment template](./azuredeploy.json).  
<img src="https://user-images.githubusercontent.com/8255007/51332226-9e42fa80-1a7b-11e9-97ec-c91de80ace1c.png" width="400">  

*Cloning or downloading the repo is not required, as the arm automation takes care for all scripts* 

It will pave the infrastructure using Pivotal [terraforming-azure](https://github.com/pivotal-cf/terraforming-azure).  
Pivotal Operations Manager will be installed and configured using Pivotal [om cli](https://github.com/pivotal-cf/om).  
PKS and Harbor Tiles  will be deployed using [om cli](https://github.com/pivotal-cf/om).  
For that, the Tiles and required Stemcell(s) are downloaded automatically.

## Supported Versions

- <a href="https://network.pivotal.io/products/ops-manager" title="OpsManager 2.4x">OpsManager 2.4x
<img src="https://dtb5pzswcit1e.cloudfront.net/assets/images/product_logos/icon_pivotal_generic@2x.png" height="16"> </a>
- <img src="https://dtb5pzswcit1e.cloudfront.net/assets/images/product_logos/icon_pivotalcontainerservice@2x.png" height="16"> Pivotal PKS 1.3.x
- <img src="https://dtb5pzswcit1e.cloudfront.net/assets/images/product_logos/icon_vmware_harbor@2x.png" height="16"> Harbor >=1.7.3
- <img src="https://dtb5pzswcit1e.cloudfront.net/assets/images/product_logos/icon_gpdb@2x.png" height="16"> Greenplum for Kubernetes 0.8.x

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
- [script for additional k8s clusters](docs/create_cluster.md)
- load balancer rules for uaa and api access

## requirements

- service principal needs to have owner rights on subscription in order to create custom roles and Managed Identities
- a [pivotal network account ( pivnet )](network.pivotal.io) and a UAA access token

## usage

there are are multiple ways to deploy the ARM template. we will describe Azure Portal Template based and az cli based Method  

### create a ssh keypair for the admin user ( if not already done )

both methods require an SSH Keypair

```bash
ssh-keygen -t rsa -f ~/${JUMPBOX_NAME} -C ${ADMIN_USERNAME}
```

### installation using Template Deployment (Preferred for First Time Users)

1. use the "deploy to Azure Button" to start a Template Deployment
<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fbottkars%2Fpks-jump-azure%2Fmaster%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>

2. fill in all required Parameters ( marked with a red Star )
![image](https://user-images.githubusercontent.com/8255007/53296940-f0fb9900-3815-11e9-9404-de801064187a.png)
3. when done, click *Purchase*.

### Installation using az cli ( for Advanced Users)

see this [Document](docs/az_cli_method.md) for installation using AZ CLI

## What´s next

When the ARM Deployment is finished, the Post Deployment jobs start

Monitor your Deployment using [debugging section](#debugging-monitoring)

When the Deployment has finished, continue to
[getting started after deployment](./initial_tasks.md)

the deployment might pause after opsmanager deployment, if your  opsmanager  fqdn is not resolvable  
the log file will, at this stage, show the Azure Name Servers that need to be added to your DNS NS Record  

![image](https://user-images.githubusercontent.com/8255007/51382000-ed3d6e00-1b15-11e9-8318-04c9f0993a1d.png)  
once fixed, the deployment will continue.

## debugging-monitoring

ssh into the Jumpbox  

```bash
 ssh -i ~/${JUMPBOX_NAME} ${ADMIN_USERNAME}@${JUMPBOX_NAME}.${AZURE_REGION}.cloudapp.azure.com
```

tail the installation log  

```bash
tail -f ~/install.log
```

### cleanup

Simply delete the Resource Groups
if using the Advances method, you may use:

```bash
az group delete --name ${JUMPBOX_RG} --yes
az group delete --name ${ENV_NAME} --yes
ssh-keygen -R "${JUMPBOX_NAME}.${AZURE_REGION}.cloudapp.azure.com"
az role definition delete --name ${SUBSCRIPTION_ID}-${ENV_NAME}-pks-worker-role
az role definition delete --name ${SUBSCRIPTION_ID}-${ENV_NAME}-pks-master-role
```

## Advanced tasks

see [advanced tasks](docs/advanced.md) that can make your life easy
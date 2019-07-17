# parameters and variables

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
 OPS_MANAGER_IMAGE  |opsManImage   | ops-manager-2.4-build.152.vhd | no  |
 PKS_DOMAIN_NAME  |   |   | yes  |
 PKS_SUBDOMAIN_NAME  |   |   | yes  |
 PKS_VERSION  |   |1.3.3 |no| Auto - Installed
 Harbor_VERSION  |   |1.7.3 |no| Auto - Installed
 Greenplum_VERSION  |   |0.81 |no| will not be Auto-Installed
 PCF_OPSMAN_USERNAME  |   | opsman  | no  |
 PKS_NOTIFICATIONS_EMAIL  |   | user@example.com  | no  | will also be used as k8sadmin email field
 PKS_AUTOPILOT  |   |TRUE   |no   |
 NET_16_BIT_MASK  |   |   | no  |
 USE_SELF_CERTS  |   | true  | no  |
 OPS_MANAGER_IMAGE_REGION  | opsmanImageRegion  | westeurope  | yes  |opsmanager image region, westus, easus, westeurope or southeasasia
WAVEFRONT_API |    WavefrontAPIUrl | |no|
WAVEFRONT_TOKEN |    WavefrontToken | |no|
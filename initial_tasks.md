# initial tasks after deployment
![image](https://user-images.githubusercontent.com/8255007/51299845-0ec12b80-1a2a-11e9-91ac-eedd39687b2f.png)

## assign teh API ASG
tbd
## configure uaac
to configure the PKS User Logins, we need to use the UAAC Admin client to generate credentials and assign user rights. 
the cf-uaac package is already installed on the Jumphost

### ssh into the Jumpbox  

```bash
source .env.sh
 ssh -i ~/${JUMPBOX_NAME} ubuntu@${JUMPBOX_NAME}.${AZURE_REGION}.cloudapp.azure.com
```

### connect to uaac api endpoint

```bash
uaac target api.${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}:8443 --skip-ssl-validation
```

sign in to uaac using the PKS UAA Management Admin Client Secret.  
You will get the secrets from the credentials tab in the PKS Tile:

<img src="https://user-images.githubusercontent.com/8255007/51299444-ce14e280-1a28-11e9-8628-1c9a6c8c5c16.png" width="400">

run 

```bash
uaac token client get admin
```
enter the client secret

create a use and assign roles:
```bash
uaac user add bottk --emails kbott@pivotal.io -p ${PIVNET_UAA_TOKEN}
uaac member add pks.clusters.admin bottk
```

## create your first cluster

from a host with PKS CLI, login with the newly created Useraccount:





![image](https://user-images.githubusercontent.com/8255007/51299130-978a9800-1a27-11e9-9da9-84887c6e08f6.png)

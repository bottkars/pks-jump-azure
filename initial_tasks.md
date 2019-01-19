# initial tasks after deployment

fine, you made it.

once the deployment is ready, a first kubernetes ( pks small, 1 master, 3 worker ) should have been deployed.

## verify the installation from the jumphost

on the jumphost, login to pks using

```bash
source .env.sh
pks login -a api.${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME} -u k8sadmin -p ${PIVNET_UAA_TOKEN} --skip-ssl-validation
```

view the deployed cluster(s)

```bash
pks clusters
pks show-cluster k8s1
```

the master and workers are grouped into Availability Sets on Azure (Aset´s).
the clusters UUID is the value to identify worker and master Aset´s .

<img width="512" alt="asets_uuid" src="https://user-images.githubusercontent.com/8255007/51423991-f1c25f00-1bc7-11e9-94c8-f826de7e30e6.png">

## connect to kubernetes dashboard from you machine

download the [pks cli](https://network.pivotal.io/products/pivotal-container-service/) from pivnet to you local machine

with your sourced local .env, login to pks

```bash
source .env
pks login -a api.${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME} -u k8sadmin -p ${PIVNET_UAA_TOKEN} --skip-ssl-validation

```

## description here to connect to first cluster
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

with your sourced local .env, login to pks and run `pks get-credentials`

```bash
source .env
pks login -a api.${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME} -u k8sadmin -p ${PIVNET_UAA_TOKEN} --skip-ssl-validation
pks get-credentials k8s1
```

<img width="512" alt="asets_uuid" src="https://user-images.githubusercontent.com/8255007/51424121-e112e880-1bc9-11e9-87d3-c509d296a356.png">  

this will create a local ~/.kube/config file.  
once done, start `kubectl proxy` on you local host.

start you browser and navigate to [kube dashboard](http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy)  

at the sign in windows, select *Browse to a kube config file*  

<img width="512" alt="asets_uuid" src="https://user-images.githubusercontent.com/8255007/51424181-bd9c6d80-1bca-11e9-99a8-7488d665700f.png">  

select the your `~/.kube/config` file created earlier  
<img width="512" alt="asets_uuid" src="https://user-images.githubusercontent.com/8255007/51424199-f4728380-1bca-11e9-9901-06a22ac869f9.png">  

*hint: mac users, `<shift><commad><g>` is your friend*  

<img width="800" alt="asets_uuid" src="https://user-images.githubusercontent.com/8255007/51424240-6d71db00-1bcb-11e9-9404-d90ffba6b29a.png">  

## connect to harbor Admin UI

to connect to the harbor ui, type https://harbor.yourpksdomin into the Browser
the login screen will open
![image](https://user-images.githubusercontent.com/8255007/53392464-bb7fb880-3999-11e9-8257-45f56056e9db.png)

enter admin as the username and you pivnet token as password

## deploying Greenplum for Kubenetes ( Operator )

tbd

## kubectl commands

tbd

## pks commands

tbd

## helm

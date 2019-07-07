# cloudnative buildpacks and pks demo walk

## Prerequirements

install docker desktop if not already done:

```bash
brew cask install docker
open /Applications/Docker.app
```

on your computer, install pack:

```bash
brew tap buildpack/tap
brew install pack
```

## get started

login to pks and get your kube credentials:

```bash
PKS_CLUSTER=k8s1 # shortcut you cluster here
pks login -a api.${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME} -u k8sadmin -p ${PIVNET_UAA_TOKEN} -k
pks get-credentials ${PKS_CLUSTER}
```

![image](https://user-images.githubusercontent.com/8255007/60766110-18585180-a0a5-11e9-8d3a-ac9f57bd7466.png)

we will use as cf nodejs demo application,
but you can use you own, for sure

clone into cf-sample-app-nodejs:

```bash
git clone https://github.com/cloudfoundry-samples/cf-sample-app-nodejs
```

![image](https://user-images.githubusercontent.com/8255007/60766139-771dcb00-a0a5-11e9-9aed-0bf72947bd53.png)

## create your first version of the app locally

```bash
cd cf-sample-app-nodejs
```

see all you current docker images:

```bash
docker images -a
```

![image](https://user-images.githubusercontent.com/8255007/60766161-c19f4780-a0a5-11e9-9079-dfaee31adeda.png)

in my example, only the microsoft/azure-cli is available locally

now we set the 'default builder' ( the base image to be used, including buildpack, run and buildimage. compare the run -image with the 'stemcell' os kind' )

```bash
pack set-default-builder cloudfoundry/cnb:cflinuxfs3
```

this creates n entry in `~/.pack/config.toml` for the default builder to use

![image](https://user-images.githubusercontent.com/8255007/60766256-90c01200-a0a7-11e9-8f57-f9eba7b2d256.png)

build first OCI Image

```bash
pack build node-demo:v1
```

this will do several things:

- download all new layers for the default builder stack
- download the run layer for the runtime

![image](https://user-images.githubusercontent.com/8255007/60766293-f7453000-a0a7-11e9-9856-775e0cf5c0bd.png)

then, the build process starts.
first, the 'Detector' will be executed to identify the runtime(s) to be used

![image](https://user-images.githubusercontent.com/8255007/60766378-32942e80-a0a9-11e9-993a-438905386827.png)

- Restoring and analyzing will restore cached packages from the downloaded image, and check for any versions of the v1 app in our local docker filesystem

![image](https://user-images.githubusercontent.com/8255007/60766415-b817de80-a0a9-11e9-8d0b-6c805c6238c8.png)

- the application will be build using NPM and Node:

![image](https://user-images.githubusercontent.com/8255007/60766430-f57c6c00-a0a9-11e9-932f-8fb71f2232a4.png)

- finally, the image will be exported locally and 

![image](https://user-images.githubusercontent.com/8255007/60766443-180e8500-a0aa-11e9-944d-03499a4725fd.png)




verify the image has been created locally on docker

```bash
docker images
```

run the image
nodejs demo runs on 4000, so we expose that port to 4000

```bash
docker run --rm -p 4000:4000 node-demo:v1
```

browse to http://localhost:4000 to view the nodejs demo app

## demo 2: create image and push version to harbor

(i assume that you have installed and configured harbor correctly or used *pks-jump-azure* )

```bash
# this is for pks-jump-azure users that have a valid .env
docker login https://harbor.${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME} --username admin --password ${PIVNET_UAA_TOKEN}
```

publish a version 2 app to harbor, this time with the bionic image

```bash
pack build harbor.${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}/library/node-demo:v2 --publish --builder cloudfoundry/cnb:bionic
```

run it locally off from you harbor registry

```bash
docker run --rm -p 4001:4000 harbor.pksazure.labbuildr.com/library/node-demo:v2
```

browse to http://localhost:4001 to view the nodejs demo app

## demo 3: Deploying it to PKS

deploying to pks also requires the correct psp´s in place.

we are using the psp´s form the [nginx demo](../templates/nginx/readme.md))

```bash
kubectl run --generator=run-pod/v1 --image=harbor.${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}/library/node-demo:v2 nodejs-demo-app --port=4000 --namespace ingress-ns
```

```bash
cat <<EOF | kubectl apply -f -
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nodejs-app
spec:
  selector:
    matchLabels:
      app: nodejs-app
  replicas: 3
  template:
    metadata:
      labels:
        app: nodejs-app
    spec:
      serviceAccountName: nginx-sa
      containers:
      - name: nodejs-v2
        image: {PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}/library/node-demo:v2
        ports:
        - containerPort: 4000
EOF
```

create the lb:

```bash
kubectl create service loadbalancer  nodejs --tcp=80:4000 -n ingress-ns
```
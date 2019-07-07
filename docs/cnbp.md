# cloudnative buildpacks and pks demo walk

## Prerequirements

on your computer, install pack

install docker desktop if not already done 

```bash
brew cask install docker
open /Applications/Docker.app
```

```bash
brew tap buildpack/tap
brew install pack
```

wde will use as cf nodejs demo application,
but you can use you own, for sure

clone into cf-sample-app-nodejs

```bash
git clone https://github.com/cloudfoundry-samples/cf-sample-app-nodejs
```

## create your first version of the app locally

```bash
cd cf-sample-app-nodejs
```

set default 'builder' ( the base image to be usded, compare it with the 'stemcell' os kind' )

```bash
pack set-default-builder cloudfoundry/cnb:cflinuxfs3
```

build first OCI Image

```bash
pack build node-demo:v1
```

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
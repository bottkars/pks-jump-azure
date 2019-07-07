# Cloudnative Buildpacks and Enterprise PKC demo walkthrough

Cloudnative Buildpacks are a new way of packing and Maintaining Docker Images using the Buildpack Technology.

let´s re-iterate how CloudFoundry would use your code to Publish an Application to the Cloud.

Having your Source Code, the only thing a Developer in Cloudfoundry Land would need to do is a `cf push`

![image](https://user-images.githubusercontent.com/8255007/60768645-9c6f0100-a0c6-11e9-9bf1-15200beebdf5.png)

the CAPI would take for all necessary steps from selecting the "runtime", creating a "container", to run the "app" and crfeate required routeing / Endpoints:

![image](https://user-images.githubusercontent.com/8255007/60768674-e8ba4100-a0c6-11e9-898d-b4b46f83c562.png)

so just one simple command to push your app to the cloud

![image](https://user-images.githubusercontent.com/8255007/60768688-2dde7300-a0c7-11e9-9bc2-de3acc28b3bd.png)

we will leverage Cloudnative Buildpacks now to leverage some Parts of that approach to create OCI compliant Images and run them on Docker and Kubernetes


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
docker images --no-trunc
```

![image](https://user-images.githubusercontent.com/8255007/60766477-99661780-a0aa-11e9-9973-f886d14f6d69.png)

run the image
nodejs demo runs on 4000, so we expose that port to 4000

```bash
docker run --rm -p 4000:4000 node-demo:v1
```

![image](https://user-images.githubusercontent.com/8255007/60766487-c4506b80-a0aa-11e9-9ca1-31d68e094a1c.png)

browse to [localhost:4000](http://localhost:4000) to view the nodejs demo app

![image](https://user-images.githubusercontent.com/8255007/60766500-ffeb3580-a0aa-11e9-9324-ccff6e85201f.png)

## demo 2: create image and push version to harbor

(i assume that you have installed and configured harbor correctly or used *pks-jump-azure* )

```bash
# this is for pks-jump-azure users that have a valid .env
docker login "https://harbor.${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}" --username admin --password ${PIVNET_UAA_TOKEN}
```

![image](https://user-images.githubusercontent.com/8255007/60767407-ec929700-a0b7-11e9-8ffd-e97cd5e2b219.png)

publish a version 2 app to harbor, this time with the bionic image

```bash
pack build harbor.${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}/library/node-demo:v2 --publish --builder cloudfoundry/cnb:bionic
```

the newer bionic stack layer needs to be downloaded:

![image](https://user-images.githubusercontent.com/8255007/60767675-5d877e00-a0bb-11e9-883b-00d8891e53b0.png)

but the run - image will be re-used:

![image](https://user-images.githubusercontent.com/8255007/60767712-accdae80-a0bb-11e9-89ab-ee3ab0b4c966.png)

now we can run the mage locally off from you harbor registry

```bash
docker run --rm -p 4001:4000 harbor.pksazure.labbuildr.com/library/node-demo:v2
```

only the diff layers (the app itself) are downloaded now.
this is one of the strength of the layered approach of Cloudnative Buildpacks, where we spilt the stack from middleware and apps.
![image](https://user-images.githubusercontent.com/8255007/60767733-ed2d2c80-a0bb-11e9-9c5c-c72b662becf8.png)

browse to [localhost:4001](http://localhost:4001) to view the nodejs demo app

## demo 3: Deploying it to PKS

deploying to pks also requires the correct psp´s in place.

we are using the psp´s form the [nginx demo](../templates/nginx/readme.md))

```bash
cat <<EOF | kubectl apply --namespace ingress-ns -f -
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
        image: harbor.${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}/library/node-demo:v2
        ports:
        - containerPort: 4000
EOF
```

![image](https://user-images.githubusercontent.com/8255007/60768187-52841c00-a0c2-11e9-96f3-f3b5b6056319.png)



view the deployment:

```bash
kubectl describe deployments/nodejs-app --namespace ingress-ns
```

![image](https://user-images.githubusercontent.com/8255007/60768385-b1966080-a0c3-11e9-9cb9-039ce617ab15.png)

in order to reach the service, we need to create an lb endpoint

create a service of tyle `loadbalancer` that mapos port 4000 to 80:

```bash
kubectl create service loadbalancer  nodejs-app --tcp=80:4000 -n ingress-ns
```

wait a view moments until the loadbalancer has been provisioned.
you can view the progress with

```bash
kubectl get service nodejs-app -n ingress-ns
```

wait for the `EXTERNAL-IP`to switch from `pending` into an extern ip.  

![image](https://user-images.githubusercontent.com/8255007/60768459-79dbe880-a0c4-11e9-9565-97f611f32e32.png)

now browse to the *external ip:80* to view the nodejs app.  

![image](https://user-images.githubusercontent.com/8255007/60768469-a132b580-a0c4-11e9-923a-3eeaeaf0dc3d.png)

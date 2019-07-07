
# PSP ingress with nginx

a walkthrough
on jummphost
cd to ~/conductor/env

## Service Accounts for Cluster

service accounts are used to access the kubeapi server
every namespace has a default SA created

## Create a namespace

```bash
kubectl create namespace ingress-ns
```

view the SA´s

```bash
kubectl get serviceAccounts
```

## create a SA for nginx

```bash
kubectl apply -f 01-service-account.yml --namespace ingress-ns
```

## create a pks priviledged psp for pks 1.3,1.2,1.1 ...

this applies only **Only if you are < PKS1.4**

```bash
kubectl create -f 02-pks-priviledged.yml
```

## Create a Role and RoleBindings for the service account of namespace

```bash
kubectl create --namespace ingress-ns -f 03-role.yml
```

```bash
kubectl create --namespace ingress-ns -f 04-role-binding.yml
```

```bash
kubectl create --namespace ingress-ns -f 05-nginx.yml
```

```bash
kubectl get events --namespace ingress-ns
kubectl describe deployment/nginx --namespace ingress-ns
```

## create a nodeport to access nginx from workers

```bash
kubectl create service nodeport nginx --tcp=80:80 -n ingress-ns
```

view the nodeport

```bash
kubectl get services -n ingress-ns
```

get the pods

```bash
kubectl get pods -n ingress-ns
```

replace ip (10.100.200.105) and pod (nginx-565b4596cf-4ggdx) with outputs from last 2 commands

```bash
kubectl exec -it nginx-565b4596cf-4ggdx -n ingress-ns  -- wget -q -O- 10.100.200.105:80
```

this will display the index html

delete the node port

```bash
kubectl delete service nginx -n ingress-ns
```

## create a loadbalancer service

```bash
kubectl create service loadbalancer  nginx --tcp=80:80 -n ingress-ns
```

get the lb ip

```bash
kubectl get services -n ingress-ns
```

use your browser to browse to the external IP

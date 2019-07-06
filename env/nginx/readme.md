
# PSP ingress with nginx

a walkthrough

## create a SA for nginx

```bash
kubectl apply -f 01-service-account.yml
```

## create a pks priviledged psp

```bash
kubectl create -f 02-pks-priviledged.yml
```

##Create a namespace

```
kubectl create namespace ingress-ns
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
kubectl describe deployment/nginx
kubectl describe rs/nginx
```
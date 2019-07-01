pfs namespace init demo -m pfs-relocated/manifest.yaml \
    -s registry-push

kubectl create namespace istio-system

kubectl create clusterrole istio-system:privileged-user \
--verb=use --resource=podsecuritypolicies \
--resource-name=pks-privileged


kubectl create clusterrolebinding istio-system:priviliged-user \
--clusterrole=istio-system:privileged-user \
--group system:authenticated \
--namespace demo




  kubectl delete clusterrole istio-system:isitorole
  kubectl delete rolebinding istio-system:istio-citadel-service-account
  kubectl delete clusterrolebinding istio-system:istio-citadel-service-account

REGISTRY=harbor.pksazure.labbuildr.com
REGISTRY_USER=admin

pfs function create uppercase \
  --git-repo https://github.com/projectriff-samples/java-boot-uppercase.git \
  --image $REGISTRY/$REGISTRY_USER/uppercase \
  --verbose




 cat <<EOF | kubectl apply -f -
kind: StorageClass
apiVersion: storage.k8s.io/v1beta1
metadata:
  name: pfs
  annotations:
    storageclass.kubernetes.io/is-default-class: 'true'
provisioner: kubernetes.io/azure-disk
parameters:
    diskformat: thin
    fstype:     ext3
EOF
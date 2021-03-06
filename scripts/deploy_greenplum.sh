#!/usr/bin/env bash
source ~/.env.sh
MYSELF=$(basename $0)
mkdir -p ${LOG_DIR}/
exec &> >(tee -a "${LOG_DIR}/${MYSELF}.$(date '+%Y-%m-%d-%H').log")
exec 2>&1
POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -n|--NO_DOWNLOAD)
    NO_DOWNLOAD="TRUE"
    shift # past argument
    #shift # past value
    ;;
    -c|--K8S_CLUSTER_NAME)
    CLUSTER="$2"
    shift # past argument
    shift # past value
    ;;
    -s|--NAMESPACE)
    NAMESPACE="$2"
    shift # past argument
    shift # past value
    ;;    
    -r|--ACR_REGISTRY)
    ACR="$2"
    shift # past argument
    shift # past value
    ;;    
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
shift
done
set -- "${POSITIONAL[@]}" # restore positional parameters
source ~/.env.sh
TOKEN=$(curl 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net' -s -H Metadata:true | jq -r .access_token)
PIVNET_UAA_TOKEN=$(curl https://${AZURE_VAULT}.vault.azure.net/secrets/PIVNETUAATOKEN?api-version=2016-10-01 -H "Authorization: Bearer ${TOKEN}" | jq -r .value)

if  [ -z ${CLUSTER} ] ; then
 echo "Please specify K8S Cluster Name with -c|--K8S_CLUSTER_NAME"
 exit 1
fi

if  [ -z ${NAMESPACE} ] ; then
 NAMESPACE=gpinstance-1
 echo "Defaulting Namespace to ${NAMESPACE}"
fi 

source ${ENV_DIR}/greenplum.env

PCF_OPSMAN_ADMIN_PASSWD=${PIVNET_UAA_TOKEN}
cd ${HOME_DIR}
#Authenticate pivnet 
DOWNLOAD_DIR_FULL=${DOWNLOAD_DIR}/${PRODUCT_SLUG}/${PCF_VERSION}
mkdir  -p ${DOWNLOAD_DIR_FULL}

PIVNET_ACCESS_TOKEN=$(curl \
  --fail \
  --header "Content-Type: application/json" \
  --data "{\"refresh_token\": \"${PIVNET_UAA_TOKEN}\"}" \
  https://network.pivotal.io/api/v2/authentication/access_tokens |\
    jq -r '.access_token')

# release by slug
RELEASE_JSON=$(curl \
  --header "Authorization: Bearer ${PIVNET_ACCESS_TOKEN}" \
  --fail \
  "https://network.pivotal.io/api/v2/products/${PRODUCT_SLUG}/releases/${RELEASE_ID}")
# eula acceptance link
EULA_ACCEPTANCE_URL=$(echo ${RELEASE_JSON} |\
  jq -r '._links.eula_acceptance.href')


# eula acceptance
curl \
  --fail \
  --header "Authorization: Bearer ${PIVNET_ACCESS_TOKEN}" \
  --request POST \
  ${EULA_ACCEPTANCE_URL}



# download product using om cli
if  [ -z ${NO_DOWNLOAD} ] ; then


echo $(date) start downloading GREENPLUM
om --env "${HOME_DIR}/om_${ENV_NAME}.env"  \
  download-product \
 --pivnet-api-token ${PIVNET_UAA_TOKEN} \
 --pivnet-file-glob "greenplum*.tar.gz" \
 --pivnet-product-slug ${PRODUCT_SLUG} \
 --product-version ${PCF_VERSION} \
 --output-directory ${DOWNLOAD_DIR_FULL}

echo $(date) end downloading GREENPLUM 


tar xzfv $DOWNLOAD_DIR_FULL/green*.tar.gz

VERSION=$(echo ${PRODUCTS} |\
  jq --arg product_name ${PRODUCT_SLUG} -r 'map(select(.name==$product_name)) | first | .version')

else 
echo ignoring download by user 
fi

cd ./greenplum-for-kubernetes*${PCF_VERSION}/

kubectl config use-context $CLUSTER

kubectl create -f ./initialize_helm_rbac.yaml

docker login harbor.${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME} -u admin -p ${PIVNET_UAA_TOKEN}
sudo cp ${HOME_DIR}/.docker/config.json ./operator/key.json
sudo chown $ADMIN_USERNAME:$ADMIN_USERNAME ./operator/key.json


$(cat <<-EOF > ./workspace/operator-values-overrides.yaml
dockerRegistryKeyJson: key.json
operatorImageRepository: harbor.${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}/library/greenplum-operator
greenplumImageRepository: harbor.${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}/library/greenplum-for-kubernetes
EOF
)


docker load -i ./images/greenplum-for-kubernetes
docker load -i ./images/greenplum-operator

GREENPLUM_IMAGE_NAME="harbor.${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}/library/greenplum-for-kubernetes:$(cat ./images/greenplum-for-kubernetes-tag)"
docker tag $(cat ./images/greenplum-for-kubernetes-id) ${GREENPLUM_IMAGE_NAME}
docker push ${GREENPLUM_IMAGE_NAME}

OPERATOR_IMAGE_NAME="harbor.${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}/library/greenplum-operator:$(cat ./images/greenplum-operator-tag)"
docker tag $(cat ./images/greenplum-operator-id) ${OPERATOR_IMAGE_NAME}
docker push ${OPERATOR_IMAGE_NAME}

helm init --wait --service-account tiller --upgrade

helm install --name greenplum-operator -f workspace/operator-values-overrides.yaml  operator/

kubectl create namespace ${NAMESPACE}
cd ~/greenplum-for-kubernetes-*/workspace
kubectl config set-context $(kubectl config current-context) --namespace=${NAMESPACE}
kubectl get all
kubectl --namespace=${NAMESPACE} apply -f ./my-gp-instance.yaml


#### edit yaml

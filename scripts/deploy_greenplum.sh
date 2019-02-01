#!/usr/bin/env bash
source .env.sh
MYSELF=$(basename $0)
mkdir -p ${HOME_DIR}/logs
exec &> >(tee -a "${HOME_DIR}/logs/${MYSELF}.$(date '+%Y-%m-%d-%H').log")
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
    -r|--ACR_REGISTRY)
    CLUSTER="$2"
    shift # past argument
    shift # past value
    ;;    
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters
source ~/.env.sh
export OM_TARGET=${PKS_OPSMAN_FQDN}
export OM_USERNAME=${PKS_OPSMAN_USERNAME}
export OM_PASSWORD="${PIVNET_UAA_TOKEN}"



START_GREENPLUM_DEPLOY_TIME=$(date)
$(cat <<-EOF >> ${HOME_DIR}/.env.sh
START_GREENPLUM_DEPLOY_TIME="${START_GREENPLUM_DEPLOY_TIME}"
EOF
)
source ${HOME_DIR}/greenplum.env

PKS_OPSMAN_ADMIN_PASSWD=${PIVNET_UAA_TOKEN}
PKS_API_HOSTNAME="api.${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}"
cd ${HOME_DIR}
#Authenticate pivnet 
DOWNLOAD_DIR_FULL=${DOWNLOAD_DIR}/${PRODUCT_SLUG}/${GREENPLUM_VERSION}
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
om --skip-ssl-validation \
  download-product \
 --pivnet-api-token ${PIVNET_UAA_TOKEN} \
 --pivnet-file-glob "greenplum*.tar.gz" \
 --pivnet-product-slug ${PRODUCT_SLUG} \
 --product-version ${GREENPLUM_VERSION} \
 --output-directory ${DOWNLOAD_DIR_FULL}

echo $(date) end downloading GREENPLUM 


tar xzfv $DOWNLOAD_DIR_FULL/green*.tar.gz

VERSION=$(echo ${PRODUCTS} |\
  jq --arg product_name ${PRODUCT_SLUG} -r 'map(select(.name==$product_name)) | first | .version')

else 
echo ignoring download by user 
fi
cat << EOF > greenplum_vars.yaml
EOF
cd ./greenplum-for-kubernetes*/

kubectl config use-context $CLUSTER

kubectl create -f ./initialize_helm_rbac.yaml
sudo cp ${HOME_DIR}/.docker/config.json ./operator/key.json
sudo chown $ADMIN_USERNAME:$ADMIN_USERNAME ./operator/key.json

ACR_LOGIN_SERVER=$(az acr list --resource-group ${ENV_NAME} \
    --query "[].{acrLoginServer:loginServer}" --output tsv)

$(cat <<-EOF > ./workspace/operator-values-overrides.yaml
dockerRegistryKeyJson: key.json
operatorImageRepository: ${ACR_LOGIN_SERVER}/greenplum-operator
greenplumImageRepository: ${ACR_LOGIN_SERVER}/greenplum-for-kubernetes
EOF
)


docker load -i ./images/greenplum-for-kubernetes
docker load -i ./images/greenplum-operator

GREENPLUM_IMAGE_NAME="${ACR_LOGIN_SERVER}/greenplum-for-kubernetes:$(cat ./images/greenplum-for-kubernetes-tag)"
docker tag $(cat ./images/greenplum-for-kubernetes-id) ${GREENPLUM_IMAGE_NAME}
docker push ${GREENPLUM_IMAGE_NAME}

OPERATOR_IMAGE_NAME="${ACR_LOGIN_SERVER}/greenplum-operator:$(cat ./images/greenplum-operator-tag)"
docker tag $(cat ./images/greenplum-operator-id) ${OPERATOR_IMAGE_NAME}
docker push ${OPERATOR_IMAGE_NAME}





helm init --wait --service-account tiller --upgrade


helm install --name greenplum-operator operator/


#### edit yaml

kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: slow
provisioner: kubernetes.io/azure-disk
parameters:
  storageaccounttype: Standard_LRS
  kind: Shared

END_GREENPLUM_DEPLOY_TIME=$(date)
echo Finished
echo Started GREENPLUM deployment at ${START_GREENPLUM_DEPLOY_TIME}
echo Finished GREENPLUM Deployment at ${END_GREENPLUM_DEPLOY_TIME}
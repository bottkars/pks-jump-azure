#!/usr/bin/env bash
source ~/.env.sh
cd ${HOME_DIR}
MYSELF=$(basename $0)
LOGDIR=
POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -n|--NO_DOWNLOAD)
    NO_DOWNLOAD=TRUE
    echo "No download is ${NO_DOWNLOAD}"
    # shift # past value if  arg value
    ;;
    -d|--DO_NOT_APPLY_CHANGES)
    NO_APPLY=TRUE
    echo "No APPLY is ${NO_APPLY}"
    # shift # past value ia arg value
    ;;
    -a|--APPLY_ALL)
    APPLY_ALL=TRUE
    echo "APPLY ALL is ${APPLY_ALL}"
    # shift # past value ia arg value
    ;;
    -t|--TILE)
    TILE="$2"
    echo "TILE IS ${TILE}"
    shift # past value ia arg value
    ;;
    -s|--LOAD_STEMCELL)
    LOAD_STEMCELL=TRUE
    echo "LOAD_STEMCELL IS ${LOAD_STEMCELL}"
    #shift # past value ia arg value
    ;;
    -u|--UPDATE_PRODUCT)
    UPDATE_PRODUCT=TRUE
    echo "UPDATE_PRODUCT IS ${UPDATE_PRODUCT}"
    #shift # past value ia arg value
    ;;          
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
shift
done
set -- "${POSITIONAL[@]}" # restore positional parameters
mkdir -p ${LOG_DIR}
exec &> >(tee -a "${LOG_DIR}/${TILE}.$(date '+%Y-%m-%d-%H').log")
exec 2>&1

echo $(date) start deploy ${TILE}

source ${ENV_DIR}/${TILE}.env
TOKEN=$(curl 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net' -s -H Metadata:true | jq -r .access_token)
PIVNET_UAA_TOKEN=$(curl https://${AZURE_VAULT}.vault.azure.net/secrets/PIVNETUAATOKEN?api-version=2016-10-01 -H "Authorization: Bearer ${TOKEN}" | jq -r .value)
PIVNET_ACCESS_TOKEN=$(curl \
  --fail \
  --header "Content-Type: application/json" \
  --data "{\"refresh_token\": \"${PIVNET_UAA_TOKEN}\"}" \
  https://network.pivotal.io/api/v2/authentication/access_tokens |\
    jq -r '.access_token')

RELEASE_JSON=$(curl \
  --header "Authorization: Bearer ${PIVNET_ACCESS_TOKEN}" \
  --fail \
  "https://network.pivotal.io/api/v2/products/${PRODUCT_SLUG}/releases/${RELEASE_ID}")
# eula acceptance link
EULA_ACCEPTANCE_URL=$(echo ${RELEASE_JSON} |\
  jq -r '._links.eula_acceptance.href')

DOWNLOAD_DIR_FULL=${DOWNLOAD_DIR}/${PRODUCT_SLUG}/${PCF_VERSION}
mkdir  -p ${DOWNLOAD_DIR_FULL}

curl \
  --fail \
  --header "Authorization: Bearer ${PIVNET_ACCESS_TOKEN}" \
  --request POST \
  ${EULA_ACCEPTANCE_URL}

###
# download product using om cli
if  [ -z ${NO_DOWNLOAD} ] ; then
echo $(date) start downloading ${PRODUCT_SLUG}

om --env "${HOME_DIR}/om_${ENV_NAME}.env"  \
  download-product \
 --pivnet-api-token ${PIVNET_UAA_TOKEN} \
 --pivnet-file-glob "*.pivotal" \
 --pivnet-product-slug ${PRODUCT_SLUG} \
 --product-version ${PCF_VERSION} \
 --output-directory ${DOWNLOAD_DIR_FULL}

echo $(date) end downloading ${PRODUCT_SLUG}

## Mignt get to 
###  do we need special, eg pks
    case ${TILE} in
    pfs)
      om --env "${HOME_DIR}/om_${ENV_NAME}.env"  \
        download-product \
        --pivnet-api-token ${PIVNET_UAA_TOKEN} \
        --pivnet-file-glob "pfs-distro-thick*" \
        --pivnet-product-slug ${PRODUCT_SLUG} \
        --product-version ${PCF_VERSION} \
        --output-directory ${DOWNLOAD_DIR_FULL}

      

      tar xzfv pfs-distro-thick-20190521164510-08b9fce9d204f44218c10fb2614ae09ea09eeafa.tgz -C ./pfs-download

      om --env "${HOME_DIR}/om_${ENV_NAME}.env"  \
        download-product \
        --pivnet-api-token ${PIVNET_UAA_TOKEN} \
        --pivnet-file-glob "pfs-cli-linux-amd64*" \
        --pivnet-product-slug ${PRODUCT_SLUG} \
        --product-version ${PCF_VERSION} \
        --output-directory ${HOME_DIR}
      ;;


    pks)
        echo $(date) start downloading PKS CLI
        om --env "${HOME_DIR}/om_${ENV_NAME}.env"  \
        download-product \
        --pivnet-api-token ${PIVNET_UAA_TOKEN} \
        --pivnet-file-glob "pks-linux-amd64*" \
        --pivnet-product-slug ${PRODUCT_SLUG} \
        --product-version ${PCF_VERSION} \
        --output-directory ${HOME_DIR}

        echo $(date) end downloading PKS CLI
        DOWNLOAD_FILE=$(cat ${HOME_DIR}/download-file.json | jq -r '.product_path')
        chmod +x ${DOWNLOAD_FILE}
        chown ${ADMIN_USERNAME}.${ADMIN_USERNAME} ${DOWNLOAD_FILE}
        sudo cp ${DOWNLOAD_FILE} /usr/local/bin/pks


        rm -rf ./kubectl-linux-amd64*
        echo $(date) start downloading kubectl
        om --env "${HOME_DIR}/om_${ENV_NAME}.env"  \
        download-product \
        --pivnet-api-token ${PIVNET_UAA_TOKEN} \
        --pivnet-file-glob "kubectl-linux-amd64*" \
        --pivnet-product-slug ${PRODUCT_SLUG} \
        --product-version ${PCF_VERSION} \
        --output-directory ${HOME_DIR}
        DOWNLOAD_FILE=$(cat ${HOME_DIR}/download-file.json | jq -r '.product_path')
        chmod +x ${DOWNLOAD_FILE}
        chown ${ADMIN_USERNAME}.${ADMIN_USERNAME} ${DOWNLOAD_FILE}
        sudo cp ${DOWNLOAD_FILE} /usr/local/bin/kubectl
        ;;
        esac
else
echo ignoring download by user
fi

TARGET_FILENAME=$(cat ${DOWNLOAD_DIR_FULL}/download-file.json | jq -r '.product_path')
# Import the tile to Ops Manager.
echo $(date) start uploading ${PRODUCT_SLUG}
om --env "${HOME_DIR}/om_${ENV_NAME}.env"  \
  --request-timeout 3600 \
  upload-product \
  --product ${TARGET_FILENAME}

echo $(date) end uploading ${PRODUCT_SLUG}

    # 1. Find the version of the product that was imported.
PRODUCTS=$(om --env "${HOME_DIR}/om_${ENV_NAME}.env"  \
  available-products \
    --format json)

VERSION=$(echo ${PRODUCTS} |\
#jq --arg product_name ${PRODUCT_SLUG} -r 'map(select(.name==$product_name)) | first | .version')
# jq --arg product_name ${PRODUCT_SLUG} --arg product_version ${PCF_VERSION} -r 'map(select(.name==$product_name and .version==$product_version))')
 jq --arg product_name ${PRODUCT_SLUG}  --arg product_version ${PCF_VERSION} -r '.[] | select(.name == $product_name) | select(.version | contains ($product_version)) | .version')


# 2.  Stage using om cli
echo $(date) start staging ${PRODUCT_SLUG}
om --env "${HOME_DIR}/om_${ENV_NAME}.env"  \
  stage-product \
  --product-name ${PRODUCT_SLUG} \
  --product-version ${VERSION}
echo $(date) end staging ${PRODUCT_SLUG}

if  [ ! -z ${LOAD_STEMCELL} ] ; then
echo "calling stemmcell_loader for LOADING Stemcells"
$SCRIPT_DIR/stemcell_loader.sh
fi


om --env "${HOME_DIR}/om_${ENV_NAME}.env"  \
assign-stemcell \
--product ${PRODUCT_SLUG} \
--stemcell latest

if [ -z ${UPDATE_PRODUCT} ] ; then
echo "Configuring Product"
om --env "${HOME_DIR}/om_${ENV_NAME}.env"  \
  configure-product \
  -c ${TEMPLATE_DIR}/${TILE}.yaml -l ${TEMPLATE_DIR}/${TILE}_vars.yaml
else
echo "Update Selected, no Product Configuration"
fi


case ${TILE} in
    pks)
    if  [ ! -z ${WAVEFRONT}  ]; then
    om --env "${HOME_DIR}/om_${ENV_NAME}.env"  \
      configure-product \
      -c ${TEMPLATE_DIR}/wavefront.yaml -l ${TEMPLATE_DIR}/${TILE}_vars.yaml
    fi
esac
echo "No Product Apply"

echo $(date) start apply ${PRODUCT_SLUG}

if  [ ! -z ${NO_APPLY} ] ; then
echo "No Product Apply"
elif [ ! -z ${APPLY_ALL} ] ; then
echo "APPLY_ALL"
om --env "${HOME_DIR}/om_${ENV_NAME}.env"  \
  apply-changes
else
echo "APPLY Product"
om --env "${HOME_DIR}/om_${ENV_NAME}.env"  \
  apply-changes \
  --product-name ${PRODUCT_SLUG}
fi

echo "checking deployed products"
om --env "${HOME_DIR}/om_${ENV_NAME}.env"  \
 deployed-products

echo $(date) end apply ${PRODUCT_SLUG}




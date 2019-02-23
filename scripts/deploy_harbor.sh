#!/usr/bin/env bash
source ~/.env.sh
cd ${HOME_DIR}
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
    NO_DOWNLOAD=TRUE
    echo "No download is ${NO_DOWNLOAD}"
    # shift # past value if  arg value
    ;;
    -d|--DO_NOT_APPLY_CHANGES)
    NO_APPLY=TRUE
    echo "No APPLY is ${NO_APPLY}"
    # shift # past value ia arg value
    ;;    
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
shift
done
set -- "${POSITIONAL[@]}" # restore positional parameters







cat << EOF > ${ENV_DIR}/harbor_vars.yaml
product_name: ${PRODUCT_SLUG}
pcf_pas_network: pcf-pas-subnet
pcf_service_network: pcf-services-subnet
azure_storage_access_key: ${HARBOR_STORAGE_KEY}
azure_account: ${ENV_SHORT_NAME}harborbackup
global_recipient_email: ${PKS_NOTIFICATIONS_EMAIL}
blob_store_base_url: blob.core.windows.net
EOF


if  [ -z ${NO_APPLY} ] ; then
${SCRIPT_DIR}/deploy_tile -t harbor
else
echo "No Product Apply"
${SCRIPT_DIR}/deploy_tile -t harbor -d
fi
echo $(date) end apply Harbor
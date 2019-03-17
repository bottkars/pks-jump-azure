#!/usr/bin/env bash
source .env.sh
MYSELF=$(basename $0)
echo "this is the updater"
mkdir -p ${LOG_DIR}
UPDATE_DIR=${HOME}/conductor/updates
mkdir -p ${UPDATE_DIR}
BASE_URI="https://raw.githubusercontent.com/bottkars/pks-jump-azure/master/"
TEMPLATE_LIST=${BASE_URI}templates/updates.txt

if ! which parallel > /dev/null; then
   sudo apt install parallel -y
fi   

wget -N -P ${UPDATE_DIR} ${TEMPLATE_LIST}
cat ${UPDATE_DIR}/updates.txt | parallel  "wget -N -P ${HOME}/conductor/templates {}"


rm -rf ${UPADTE_DIR}


# wget -O - https://raw.githubusercontent.com/bottkars/pks-jump-azure/master/scripts/update.sh | bash


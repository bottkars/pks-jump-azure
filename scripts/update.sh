#!/usr/bin/env bash
source .env.sh
MYSELF=$(basename $0)
echo "this is the updater"
mkdir -p ${LOG_DIR}
UPDATE_DIR=${HOME}/conductor/updates
mkdir -p ${UPDATE_DIR}
BASE_URI="https://raw.githubusercontent.com/bottkars/pks-jump-azure/master/"
TEMPLATE_LIST=${UPDATE_DIR} ${BASE_URI}/templates/templates.txt
wget -P ${UPDATE_DIR} ${TEMPLATE_LIST}
cat ${UPADTE_DIR}/templates.txt | parallel --gnu "wget -P ${HOME}/conductor/templates {}"
rm -rf ${UPADTE_DIR}/templates.txt


# wget -O - https://raw.githubusercontent.com/bottkars/pks-jump-azure/master/scripts/update.sh | bash


#!/usr/bin/env bash
source .env.sh
MYSELF=$(basename $0)
echo "this is the updater"
mkdir -p ${LOG_DIR}
UPDATE_DIR=${HOME}/conductor/updates/
mkdir -p ${UPDATE_DIR}
BASE_URI="https://raw.githubusercontent.com/bottkars/pks-jump-azure/master/"
wget -p ${UPDATE_DIR} ${BASE_URI}/templates/updatefiles.txt
# cat urlfile | parallel --gnu "wget {}"


# wget -O - https://raw.githubusercontent.com/bottkars/pks-jump-azure/master/scripts/update.sh | bash


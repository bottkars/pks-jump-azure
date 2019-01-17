source ~/.env.sh
export OM_TARGET=${PKS_OPSMAN_FQDN}
export OM_USERNAME=${PKS_OPSMAN_USERNAME}
export OM_PASSWORD="${PIVNET_UAA_TOKEN}"
export $( \
  om \
    --skip-ssl-validation \
    curl \
      --silent \
      --path /api/v0/deployed/director/credentials/bosh_commandline_credentials | \
        jq --raw-output '.credential' \
)

sudo mkdir -p /var/tempest/workspaces/default

sudo sh -c \
  "om \
    --skip-ssl-validation \
    --target ${PKS_OPSMAN_FQDN} \
    --username ${PKS_OPSMAN_USERNAME} \
    --password ${PIVNET_UAA_TOKEN} \
    curl \
      --silent \
      --path "/api/v0/security/root_ca_certificate" |
        jq --raw-output '.root_ca_certificate_pem' \
          > /var/tempest/workspaces/default/root_ca_certificate"
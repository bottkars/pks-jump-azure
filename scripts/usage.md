curl "https://pcf.${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}/download_root_ca_cert \
      -X GET \
      -H "Authorization: Bearer YOUR-UAA-ACCESS-TOKEN"
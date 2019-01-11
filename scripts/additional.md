# additional assumptions

## uaac client

```bash
sudo apt-get install ruby ruby-dev gcc libffi-dev make build-essential -y
# get pivnet UAA TOKEN
gem install cf-uaac
```


```bash
uaac target ${PKS_OPSMAN_FQDN}/uaa --skip-ssl-validation
uaac token owner get opsman "${PKS_OPSMAN_USERNAME}" -s "" -p ${PIVNET_UAA_TOKEN}
APITOKEN=$(uaac contexts | grep "$OPSMAN_IP" -A6 | grep access_token | cut -d ':' -f  2 | cut -d ' ' -f 2)
```
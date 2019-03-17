cd ~/pivotal-cf-terraforming-azure*/terraforming-pks
PATCH_SERVER="https://raw.githubusercontent.com/bottkars/pks-jump-azure/master/patches/"
wget -q ${PATCH_SERVER}main.tf -O ./main.tf
wget -q ${PATCH_SERVER}variables.tf -O ./variables.tf
wget -q ${PATCH_SERVER}modules/pks/networking.tf -O ../modules/pks/networking.tf
wget -q ${PATCH_SERVER}modules/pks/variables.tf -O ../modules/pks/variables.tf
terraform apply -target=azurerm_subnet.lb_services --auto-approve
terraform apply -target=azurerm_subscription.primary --auto-approve



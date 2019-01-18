# initial tasks after deployment
![image](https://user-images.githubusercontent.com/8255007/51299845-0ec12b80-1a2a-11e9-91ac-eedd39687b2f.png)

## assign the API ASG

~~as a manual task, assign inbund port rule to 8443 and 9021 for bosh-deployed-vm´s NSG
there is currently rework in the terraform scripts for that
( automated in next drop )~~

## configure uaac

~~to configure the PKS User Logins, we need to use the UAAC Admin client to generate credentials and assign user rights. 
the cf-uaac package is already installed on the Jumphost~~

## description here to connect to first cluster
# Install an App Service with a service endpoint with outbound traffic routed through a Firewall and inbound traffic coming through an App Gateway.

Update May 2020 - This script will no longer be updated in favour of the Terraform script, it has been archived for future reference (just in case)
Note: This installs the same as the Terraform script but doesn't include the option to install the custom DNS as a scaleset (single vm only)

## Prerequisites: 
For the Azure CLI script I am running them on Ubuntu in the Windows Subsystem for Linux (WSL v1).  I have installed jq to make json parsing a little easier.  To install it yourself use `sudo apt-get install jq`.
To Zip powershell modules ready to upload to blob I am using the zip package `sudo apt install zip`
You will need to provide a password for the DNS VM Scaleset.  AzureAdmin is the default user name.

## Run the script 
The script can be be found [here](./Setup.sh), it was designed in Ubuntu running on WSL. (Your mileage may vary if you run this on something else). I am running it with `bash setup.sh`  (Note: If you run this on ubuntu with the `sh setup.sh` command it will fail with a Bad Substitution error, this is because I am using a bash specific substring call that is not understood by sh/dash)
The script relies on globally unique names so change the PREFIX variable before you run this.
Make sure you change the LOC varaible to your required region.  (a list of regions can be found by running the following command `az account list-locations --query "[].name" -o tsv`)
Note: The script can take up to 60 minutes to run (provisioning an Application Gateway can take time).

## Clean up
I have added a delete-all script [here](./delete-all.sh) to remove all the resource groups (you will need to tweak the PREFIX variable).  Note: This deletes everything unprompted so be sure you want to use it!  (`bash delete-all.sh`)
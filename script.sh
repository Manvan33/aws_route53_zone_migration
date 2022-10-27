#!/bin/bash
# Script that migrates a route53 hosted zone from one AWS account to another using the aws CLI

install_aws_cli() {
    echo "Installing AWS cli"
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
}

# Install AWS CLI if not already installed
# https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html#getting-started-install-instructions

aws --version 2>/dev/null && echo "AWS CLI already installed" || install_aws_cli

# https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html
echo "Configuring AWS CLI with source account credentials"
aws configure --profile source

# show list of hosted zones
echo "List of hosted zones in source account:"
aws --profile source route53 list-hosted-zones | jq '.HostedZones[].Name + " :" + .HostedZones[].Id'
# Fetch records from source zone
echo -n "Enter source zone id: "
read source_zone_id
if [ -z "$source_zone_id" ]; then
    echo "Source zone id cannot be empty"
    exit 1
fi
echo "Fetching records from source zone"
aws --profile source route53 list-resource-record-sets --hosted-zone-id $source_zone_id >source_zone.json
echo "Found $(cat source_zone.json | grep "ResourceRecords" | wc -l) record in source zone"
echo "Generating JSON for target zone"
python3 parser.py >destination_zone.json
echo "Found $(cat destination_zone.json | grep "ResourceRecordSet" | wc -l) record in target json"

# Configure AWS CLI with destination account credentials
echo "Configuring AWS CLI with destination account credentials"
aws configure --profile destination

# Create new zone
echo -n "Enter new zone domain: "
read new_zone_name
if [ -z "$new_zone_name" ]; then
    echo "New zone domain cannot be empty"
    exit 1
fi
echo "Creating new zone"
aws --profile destination route53 create-hosted-zone --name $new_zone_name --caller-reference $(date +%s) >new_zone.json
new_zone_id=$(cat new_zone.json | grep "Location" | cut -d '"' -f 4 | rev | cut -d "/" -f 1 | rev)
echo "New zone created with id $new_zone_id"

# Create records in new zone
echo "Creating records in new zone"
aws --profile destination route53 change-resource-record-sets --hosted-zone-id $new_zone_id --change-batch file://destination_zone.json
# checking if the records are created
echo -n $(aws --profile destination route53 list-resource-record-sets --hosted-zone-id $new_zone_id | grep "ResourceRecords" | wc -l)
echo " records created in new zone"

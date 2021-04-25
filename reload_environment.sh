#!/bin/bash

echo ===============================================================
echo This script will be DELETE the terraform state and kubeconfig!!
echo ===============================================================
echo Continue? only 'yes' will be accepted
read continue
echo ""

if [ "$continue" != "yes" ]; then
  exit
fi

rm kubeconfig 2> /dev/null
rm terraform.tfstate* 2> /dev/null

aws --profile sandbox configure

public_domain=$(aws route53 list-hosted-zones --profile sandbox | jq -r ".HostedZones | .[0].Name" | sed -E "s/(.*)\./\1/")
echo "Using '${public_domain}' as public domain"
sed -E -i .bkp "s/(public_domain=\").*(\")/\1${public_domain}\2/g" terraform.tfvars
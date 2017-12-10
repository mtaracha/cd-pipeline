#!/bin/bash

ACTION=$1
SECURITY_GROUP_ID=sg-xxxxxxx
PUBLIC_IP_ADDRESS=$(wget -qO- http://checkip.amazonaws.com)
PUBLIC_IP_ADDRESS_CIDR=$PUBLIC_IP_ADDRESS/32

if [ "$ACTION" = "authorize" ]
then
  aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 443 --cidr $PUBLIC_IP_ADDRESS_CIDR --region eu-west-1 || exit 1
  echo "CircleCi - $PUBLIC_IP_ADDRESS - access granted"
elif [ "$ACTION" = "revoke" ]
then
  aws ec2 revoke-security-group-ingress --group-id $SECURITY_GROUP_ID --ip-permissions '[{"IpProtocol": "tcp", "FromPort": 443, "ToPort": 443, "IpRanges": [{"CidrIp": "'"${PUBLIC_IP_ADDRESS_CIDR}"'"}]}]' --region eu-west-1
  echo "CircleCi - $PUBLIC_IP_ADDRESS - access revoked"
else
  echo "Bad argument"
  exit 1
fi

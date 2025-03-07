#!/bin/bash

source scripts/teardown-aws/logging-and-sanitisation.sh

delete_security_groups() {
  vpc_id=$1
  echo "Retrieving Security Groups for VPC: $vpc_id..."

  security_group_ids=$(aws ec2 describe-security-groups \
    --filters "Name=vpc-id,Values=$vpc_id" \
    --query "SecurityGroups[?GroupName!='default'].GroupId" --output text)

  if [ -z "$security_group_ids" ]; then
    echo "No non-default Security Groups found for VPC: $vpc_id"
    return
  fi

  for sg_id in $security_group_ids; do
    echo "Deleting Security Group: $sg_id"
    
    if aws ec2 delete-security-group --group-id "$sg_id"; then
      echo "[ERROR] Failed to delete Security Group: $sg_id"
    else
      echo "Successfully deleted Security Group: $sg_id"
    fi
  done
}

# Function to release Elastic IPs
release_elastic_ips() {
  echo "Releasing Elastic IPs..."
  allocation_ids=$(aws ec2 describe-addresses --query "Addresses[].AllocationId" --output text)

  if [ -n "$allocation_ids" ]; then
    for alloc_id in $allocation_ids; do
      echo "Releasing Elastic IP: $alloc_id"
      aws ec2 release-address --allocation-id "$alloc_id"
    done
  fi
}

# Function to delete NAT Gateways
delete_nat_gateways() {
  vpc_id=$1
  echo "Retrieving NAT Gateways for VPC: $vpc_id..."
  nat_gateway_ids=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$vpc_id" --query "NatGateways[].NatGatewayId" --output text)

  if [ -n "$nat_gateway_ids" ]; then
    for nat_id in $nat_gateway_ids; do
      echo "Deleting NAT Gateway: $nat_id"
      aws ec2 delete-nat-gateway --nat-gateway-id "$nat_id"
      sleep 5  # Give AWS some time to process deletion
    done
  fi
}

# Function to delete Internet Gateways (handling DependencyViolation)
delete_internet_gateways() {
  vpc_id=$1
  echo "Retrieving Internet Gateways for VPC: $vpc_id..."
  igw_ids=$(aws ec2 describe-internet-gateways \
    --filters "Name=attachment.vpc-id,Values=$vpc_id" \
    --query "InternetGateways[].InternetGatewayId" --output text)

  if [ -n "$igw_ids" ]; then
    for igw_id in $igw_ids; do
      echo "Detaching and deleting Internet Gateway: $igw_id"

      # Release public IPs first to avoid DependencyViolation
      release_elastic_ips

      aws ec2 detach-internet-gateway --internet-gateway-id "$igw_id" --vpc-id "$vpc_id"
      sleep 3  # AWS sometimes needs a delay before deletion

      aws ec2 delete-internet-gateway --internet-gateway-id "$igw_id"
    done
  fi
}

# Function to delete Subnets
delete_subnets() {
  vpc_id=$1
  echo "Retrieving Subnets for VPC: $vpc_id..."
  subnet_ids=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" --query "Subnets[].SubnetId" --output text)

  if [ -n "$subnet_ids" ]; then
    for subnet_id in $subnet_ids; do
      echo "Deleting Subnet: $subnet_id"
      aws ec2 delete-subnet --subnet-id "$subnet_id"
    done
  fi
}

# Function to delete Route Tables
delete_route_tables() {
  vpc_id=$1
  echo "Retrieving Route Tables for VPC: $vpc_id..."
  route_table_ids=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$vpc_id" --query "RouteTables[].RouteTableId" --output text)

  if [ -n "$route_table_ids" ]; then
    for rt_id in $route_table_ids; do
      echo "Deleting Route Table: $rt_id"

      # Disassociate any subnet associations first
      association_ids=$(aws ec2 describe-route-tables --route-table-ids "$rt_id" --query "RouteTables[0].Associations[].RouteTableAssociationId" --output text)
      for assoc_id in $association_ids; do
        aws ec2 disassociate-route-table --association-id "$assoc_id"
      done

      aws ec2 delete-route-table --route-table-id "$rt_id"
    done
  fi
}

# Function to delete a VPC
delete_vpc() {
  vpc_id=$1
  echo "Processing VPC: $vpc_id"

  delete_nat_gateways "$vpc_id"
  delete_internet_gateways "$vpc_id"
  delete_subnets "$vpc_id"
  delete_security_groups "$vpc_id"
  delete_route_tables "$vpc_id"

  echo "Deleting VPC: $vpc_id"
  aws ec2 delete-vpc --vpc-id "$vpc_id"
}

# Main Script: Delete all VPCs matching the environment
echo "Retrieving VPCs with prefix: '${DEPLOY_ENV}'..."
vpc_ids=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=${DEPLOY_ENV}" --query "Vpcs[].VpcId" --output text)

if [ -n "$vpc_ids" ]; then
  for vpc_id in $vpc_ids; do
    delete_vpc "$vpc_id"
  done
else
  echo "No VPCs found for ${DEPLOY_ENV}"
fi

#!/bin/bash

source scripts/teardown-aws/logging-and-sanitisation.sh

# Function to delete Internet Gateways
delete_internet_gateways() {
  vpc_id=$1
  echo "Retrieving Internet Gateways associated with VPC: $vpc_id..."
  igw_ids=$(aws ec2 describe-internet-gateways \
    --filters "Name=attachment.vpc-id,Values=$vpc_id" \
    --query "InternetGateways[].InternetGatewayId" --output text)

  if [ -z "$igw_ids" ]; then
    echo "No Internet Gateways found for VPC: $vpc_id"
    return
  fi

  for igw_id in $igw_ids; do
    echo "Detaching and deleting Internet Gateway: $igw_id"

    if ! aws ec2 detach-internet-gateway --internet-gateway-id "$igw_id" --vpc-id "$vpc_id"; then
      echo "[ERROR] Failed to detach Internet Gateway: $igw_id"
      continue
    fi

    if ! aws ec2 delete-internet-gateway --internet-gateway-id "$igw_id"; then
      echo "[ERROR] Failed to delete Internet Gateway: $igw_id"
    else
      echo "Successfully deleted Internet Gateway: $igw_id"
    fi
  done
}

# Function to delete VPC Endpoints
delete_vpc_endpoints() {
  vpc_id=$1
  echo "Retrieving VPC Endpoints associated with VPC: $vpc_id..."
  endpoint_ids=$(aws ec2 describe-vpc-endpoints \
    --filters "Name=vpc-id,Values=$vpc_id" \
    --query "VpcEndpoints[].VpcEndpointId" --output text)

  if [ -z "$endpoint_ids" ]; then
    echo "No VPC Endpoints found for VPC: $vpc_id"
    return
  fi

  for endpoint_id in $endpoint_ids; do
    echo "Deleting VPC Endpoint: $endpoint_id"
    if ! aws ec2 delete-vpc-endpoints --vpc-endpoint-ids "$endpoint_id"; then
      echo "[ERROR] Failed to delete VPC Endpoint: $endpoint_id"
    else
      echo "Successfully deleted VPC Endpoint: $endpoint_id"
    fi
  done
}

# Function to delete Subnets
delete_subnets() {
  vpc_id=$1
  echo "Retrieving Subnets associated with VPC: $vpc_id..."
  subnet_ids=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$vpc_id" \
    --query "Subnets[].SubnetId" --output text)

  if [ -z "$subnet_ids" ]; then
    echo "No Subnets found for VPC: $vpc_id"
    return
  fi

  for subnet_id in $subnet_ids; do
    echo "Deleting Subnet: $subnet_id"

    if ! aws ec2 delete-subnet --subnet-id "$subnet_id"; then
      echo "[ERROR] Failed to delete Subnet: $subnet_id"
    else
      echo "Successfully deleted Subnet: $subnet_id"
    fi
  done
}

# Function to delete Route Tables
delete_route_tables() {
  vpc_id=$1
  echo "Retrieving Route Tables associated with VPC: $vpc_id..."

  route_table_ids=$(aws ec2 describe-route-tables \
    --filters "Name=vpc-id,Values=$vpc_id" \
    --query "RouteTables[].RouteTableId" --output text)

  if [ -z "$route_table_ids" ]; then
    echo "No Route Tables found for VPC: $vpc_id"
    return
  fi

  for rt_id in $route_table_ids; do
    echo "Attempting to delete Route Table: $rt_id"

    # Disassociate any associations
    association_ids=$(aws ec2 describe-route-tables \
      --route-table-ids "$rt_id" \
      --query "RouteTables[0].Associations[].RouteTableAssociationId" --output text)

    for assoc_id in $association_ids; do
      echo "Disassociating Route Table Association: $assoc_id"
      if ! aws ec2 disassociate-route-table --association-id "$assoc_id"; then
        echo "[ERROR] Failed to disassociate Route Table Association: $assoc_id"
      fi
    done

    # Attempt to delete the route table
    if ! aws ec2 delete-route-table --route-table-id "$rt_id"; then
      echo "[ERROR] Failed to delete Route Table: $rt_id"
    else
      echo "Successfully deleted Route Table: $rt_id"
    fi
  done
}

# Function to delete VPC
delete_vpc() {
  vpc_id=$1
  echo "Deleting VPC: $vpc_id"

  delete_vpc_endpoints "$vpc_id"
  delete_internet_gateways "$vpc_id"
  delete_subnets "$vpc_id"
  delete_route_tables "$vpc_id"

  echo "Attempting to delete VPC: $vpc_id"
  if ! aws ec2 delete-vpc --vpc-id "$vpc_id"; then
    echo "[ERROR] Failed to delete VPC: $vpc_id"
  else
    echo "Successfully deleted VPC: $vpc_id"
  fi
}

# Main Execution
echo "Deleting VPCs..."
vpc_ids=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=${DEPLOY_ENV}" --query "Vpcs[].VpcId" --output text)

if [ -n "$vpc_ids" ]; then
  for vpc_id in $vpc_ids; do
    delete_vpc "$vpc_id"
  done
else
  echo "No VPCs found for ${DEPLOY_ENV}"
fi

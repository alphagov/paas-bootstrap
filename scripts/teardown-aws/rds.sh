#!/bin/bash

source scripts/teardown-aws/logging-and-sanitisation.sh

delete_rds_instance() {
  local instance_id="$1"
  echo "Deleting RDS Instance: $instance_id"

  # Attempt to delete the RDS instance
  aws rds delete-db-instance \
    --db-instance-identifier "$instance_id" \
    --skip-final-snapshot

  if [ $? -ne 0 ]; then
    log_error "Failed to delete RDS Instance: $instance_id"
  else
    echo "Successfully deleted RDS Instance: $instance_id"
  fi
}

# Main RDS Instances Deletion Function
delete_rds_instances() {
  echo "Deleting RDS Instances..."

  # Get the list of instances that match the DEPLOY_ENV
  instance_list=$(aws rds describe-db-instances \
    --query "DBInstances[?contains(DBInstanceIdentifier, '${DEPLOY_ENV}')].DBInstanceIdentifier" \
    --output text)

  # Loop through each instance identifier and delete it
  for instance_id in $instance_list; do
    if [ -n "$instance_id" ]; then
      delete_rds_instance "$instance_id"
    else
      log_error "Empty or invalid RDS Instance identifier."
    fi
  done
}

# Helper function to delete a single RDS Subnet Group
delete_rds_subnet_group() {
  local subnet_group_name="$1"
  echo "Attempting to delete RDS Subnet Group: $subnet_group_name"

  # Check if the subnet group exists before attempting deletion
  aws rds describe-db-subnet-groups --db-subnet-group-name "$subnet_group_name" > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    # The subnet group exists, proceed with deletion
    aws rds delete-db-subnet-group --db-subnet-group-name "$subnet_group_name"
    if [ $? -ne 0 ]; then
      log_error "Failed to delete RDS Subnet Group: $subnet_group_name"
    else
      echo "Successfully deleted RDS Subnet Group: $subnet_group_name"
    fi
  else
    echo "RDS Subnet Group does not exist: $subnet_group_name"
    log_error "RDS Subnet Group not found: $subnet_group_name"
  fi
}

# Main RDS Subnet Group Deletion Function
delete_rds_subnet_groups() {
  echo "Deleting RDS Subnet Groups..."

  # Get the list of subnet groups that match the DEPLOY_ENV
  subnet_group_list=$(aws rds describe-db-subnet-groups \
    --query "DBSubnetGroups[?contains(DBSubnetGroupName, '${DEPLOY_ENV}')].DBSubnetGroupName" \
    --output text)

  # Loop through each subnet group name and delete it
  for subnet_group_name in $subnet_group_list; do
    if [ -n "$subnet_group_name" ]; then
      delete_rds_subnet_group "$subnet_group_name"
    else
      log_error "Empty or invalid RDS Subnet Group identifier."
    fi
  done
}

# Helper function to delete a single RDS Parameter Group
delete_rds_parameter_group() {
  local parameter_group_name="$1"
  echo "Attempting to delete RDS Parameter Group: $parameter_group_name"

  # Check if the parameter group exists before attempting deletion
  aws rds describe-db-parameter-groups --db-parameter-group-name "$parameter_group_name" > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    # The parameter group exists, proceed with deletion
    aws rds delete-db-parameter-group --db-parameter-group-name "$parameter_group_name"
    if [ $? -ne 0 ]; then
      log_error "Failed to delete RDS Parameter Group: $parameter_group_name"
    else
      echo "Successfully deleted RDS Parameter Group: $parameter_group_name"
    fi
  else
    echo "RDS Parameter Group does not exist: $parameter_group_name"
    log_error "RDS Parameter Group not found: $parameter_group_name"
  fi
}

# Main RDS Parameter Group Deletion Function
delete_rds_parameter_groups() {
  echo "Deleting RDS Parameter Groups..."

  # Get the list of parameter groups that match the DEPLOY_ENV
  parameter_group_list=$(aws rds describe-db-parameter-groups \
    --query "DBParameterGroups[?contains(DBParameterGroupName, '${DEPLOY_ENV}')].DBParameterGroupName" \
    --output text)

  # Loop through each parameter group name and delete it
  for parameter_group_name in $parameter_group_list; do
    if [ -n "$parameter_group_name" ]; then
      delete_rds_parameter_group "$parameter_group_name"
    else
      log_error "Empty or invalid RDS Parameter Group identifier."
    fi
  done
}

# Main script execution
echo "Starting cleanup for resources associated with $DEPLOY_ENV..."

# Execute cleanup functions
delete_rds_instances
delete_rds_subnet_groups
delete_rds_parameter_groups

echo "Cleanup completed for resources associated with $DEPLOY_ENV."

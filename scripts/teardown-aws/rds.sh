#!/bin/bash

source scripts/teardown-aws/logging-and-sanitisation.sh

delete_rds_instance() {
  local instance_id="$1"
  echo "Deleting RDS Instance: $instance_id"

  if aws rds delete-db-instance --db-instance-identifier "$instance_id" --skip-final-snapshot; then
    echo "Successfully deleted RDS Instance: $instance_id"
  else
    log_error "Failed to delete RDS Instance: $instance_id"
  fi
}

delete_rds_instances() {
  echo "Deleting RDS Instances..."

  # Get the list of instances that match the DEPLOY_ENV
  aws rds describe-db-instances \
    --query "DBInstances[?contains(DBInstanceIdentifier, '${DEPLOY_ENV}')].DBInstanceIdentifier" \
    --output text | while read -r instance_id; do
      if [ -n "$instance_id" ]; then
        delete_rds_instance "$instance_id"
      else
        log_error "Empty or invalid RDS Instance identifier."
      fi
    done
}

delete_rds_subnet_group() {
  local subnet_group_name="$1"
  echo "Attempting to delete RDS Subnet Group: $subnet_group_name"

  if aws rds describe-db-subnet-groups --db-subnet-group-name "$subnet_group_name" > /dev/null 2>&1; then
    if aws rds delete-db-subnet-group --db-subnet-group-name "$subnet_group_name"; then
      echo "Successfully deleted RDS Subnet Group: $subnet_group_name"
    else
      log_error "Failed to delete RDS Subnet Group: $subnet_group_name"
    fi
  else
    echo "RDS Subnet Group does not exist: $subnet_group_name"
  fi
}

delete_rds_subnet_groups() {
  echo "Deleting RDS Subnet Groups..."

  aws rds describe-db-subnet-groups \
    --query "DBSubnetGroups[?contains(DBSubnetGroupName, '${DEPLOY_ENV}')].DBSubnetGroupName" \
    --output text | while read -r subnet_group_name; do
      if [ -n "$subnet_group_name" ]; then
        delete_rds_subnet_group "$subnet_group_name"
      else
        log_error "Empty or invalid RDS Subnet Group identifier."
      fi
    done
}

delete_rds_parameter_group() {
  local parameter_group_name="$1"
  echo "Attempting to delete RDS Parameter Group: $parameter_group_name"

  if aws rds describe-db-parameter-groups --db-parameter-group-name "$parameter_group_name" > /dev/null 2>&1; then
    if aws rds delete-db-parameter-group --db-parameter-group-name "$parameter_group_name"; then
      echo "Successfully deleted RDS Parameter Group: $parameter_group_name"
    else
      log_error "Failed to delete RDS Parameter Group: $parameter_group_name"
    fi
  else
    echo "RDS Parameter Group does not exist: $parameter_group_name"
  fi
}

delete_rds_parameter_groups() {
  echo "Deleting RDS Parameter Groups..."

  aws rds describe-db-parameter-groups \
    --query "DBParameterGroups[?contains(DBParameterGroupName, '${DEPLOY_ENV}')].DBParameterGroupName" \
    --output text | while read -r parameter_group_name; do
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

echo "RDS Cleanup completed for resources associated with $DEPLOY_ENV."

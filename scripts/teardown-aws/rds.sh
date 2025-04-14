#!/bin/bash

source scripts/teardown-aws/logging-and-sanitisation.sh

delete_rds_instance() {
  local instance_id="$1"
  echo "Deleting RDS Instance: '$instance_id'"

  if [[ -n "$instance_id" ]]; then
    if aws rds delete-db-instance --db-instance-identifier "$instance_id" --skip-final-snapshot; then
      echo "Successfully deleted RDS Instance: $instance_id"
    else
      log_error "Failed to delete RDS Instance: $instance_id"
    fi
  else
    log_error "Empty or invalid RDS Instance identifier."
  fi
}

delete_rds_instances() {
  echo "Deleting RDS Instances..."

  for instance_id in $(aws rds describe-db-instances \
    --query "DBInstances[?contains(DBInstanceIdentifier, '${DEPLOY_ENV}')].DBInstanceIdentifier" \
    --output text | tr -d '\r' | xargs); do

    # Log extracted values
    echo "Found RDS Instance ID: '$instance_id'"

    # Clean up potential whitespace issues
    instance_id=$(echo "$instance_id" | xargs)

    if [[ -n "$instance_id" ]]; then
      delete_rds_instance "$instance_id"
    else
      log_error "Invalid RDS Instance identifier: '$instance_id'"
    fi
  done
}

delete_rds_subnet_group() {
  local subnet_group_name="$1"
  echo "Attempting to delete RDS Subnet Group: '$subnet_group_name'"

  if [[ -n "$subnet_group_name" ]]; then
    if aws rds delete-db-subnet-group --db-subnet-group-name "$subnet_group_name"; then
      echo "Successfully deleted RDS Subnet Group: $subnet_group_name"
    else
      log_error "Failed to delete RDS Subnet Group: $subnet_group_name"
    fi
  else
    log_error "Invalid or empty Subnet Group name."
  fi
}

delete_rds_subnet_groups() {
  echo "Deleting RDS Subnet Groups..."

  for subnet_group_name in $(aws rds describe-db-subnet-groups \
    --query "DBSubnetGroups[?contains(DBSubnetGroupName, '${DEPLOY_ENV}')].DBSubnetGroupName" \
    --output text | tr -d '\r' | xargs); do

    echo "Found RDS Subnet Group: '$subnet_group_name'"

    subnet_group_name=$(echo "$subnet_group_name" | xargs)

    if [[ -n "$subnet_group_name" ]]; then
      delete_rds_subnet_group "$subnet_group_name"
    fi
  done
}

delete_rds_parameter_group() {
  local parameter_group_name="$1"
  echo "Attempting to delete RDS Parameter Group: '$parameter_group_name'"

  if [[ -n "$parameter_group_name" ]]; then
    if aws rds delete-db-parameter-group --db-parameter-group-name "$parameter_group_name"; then
      echo "Successfully deleted RDS Parameter Group: $parameter_group_name"
    else
      log_error "Failed to delete RDS Parameter Group: $parameter_group_name"
    fi
  else
    log_error "Invalid or empty Parameter Group name."
  fi
}

delete_rds_parameter_groups() {
  echo "Deleting RDS Parameter Groups..."

  for parameter_group_name in $(aws rds describe-db-parameter-groups \
    --query "DBParameterGroups[?contains(DBParameterGroupName, '${DEPLOY_ENV}')].DBParameterGroupName" \
    --output text | tr -d '\r' | xargs); do

    echo "Found RDS Parameter Group: '$parameter_group_name'"

    parameter_group_name=$(echo "$parameter_group_name" | xargs)

    if [[ -n "$parameter_group_name" ]]; then
      delete_rds_parameter_group "$parameter_group_name"
    fi
  done
}

# Main script execution
echo "Starting cleanup for resources associated with $DEPLOY_ENV..."

delete_rds_instances
delete_rds_subnet_groups
delete_rds_parameter_groups

echo "RDS Cleanup completed for resources associated with $DEPLOY_ENV."

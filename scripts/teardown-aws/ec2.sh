#!/bin/bash

source scripts/teardown-aws/logging-and-sanitisation.sh

echo "Starting cleanup for resources associated with ${DEPLOY_ENV}..."

# 1. Delete Load Balancers
echo "Deleting Load Balancers..."
#
# Get the list of load balancers for ALBs/NLBs
alb_lb_arns=$(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?contains(LoadBalancerName, '${DEPLOY_ENV}')].LoadBalancerArn" \
  --output text)

# Get the list of load balancers for CLBs
clb_lb_names=$(aws elb describe-load-balancers \
  --query "LoadBalancerDescriptions[?contains(LoadBalancerName, '${DEPLOY_ENV}')].LoadBalancerName" \
  --output text)

# Delete ALBs/NLBs
if [ -n "$alb_lb_arns" ]; then
  for lb_arn in $alb_lb_arns; do
    echo "Deleting ALB/NLB: $lb_arn"
    aws elbv2 delete-load-balancer --load-balancer-arn "$lb_arn"
    if [ $? -eq 0 ]; then
      echo "Successfully deleted ALB/NLB: $lb_arn"
    else
      echo "[ERROR] Failed to delete ALB/NLB: $lb_arn"
    fi
  done
fi

# Delete CLBs
if [ -n "$clb_lb_names" ]; then
  for lb_name in $clb_lb_names; do
    echo "Deleting CLB: $lb_name"
    aws elb delete-load-balancer --load-balancer-name "$lb_name"
    if [ $? -eq 0 ]; then
      echo "Successfully deleted CLB: $lb_name"
    else
      echo "[ERROR] Failed to delete CLB: $lb_name"
    fi
  done
fi

# 2. Terminate EC2 Instances
terminate_instances() {
  deploy_env=$1
  echo "Terminating EC2 instances for DEPLOY_ENV=${deploy_env}..."

  instance_ids=$(aws ec2 describe-instances \
    --filters "Name=tag:deploy_env,Values=$deploy_env" \
    --query "Reservations[].Instances[?State.Name != 'terminated'].InstanceId" \
    --output text)

  if [ -z "$instance_ids" ]; then
    echo "No EC2 instances found for DEPLOY_ENV=${deploy_env}"
    return
  fi

  echo "Terminating instances: $instance_ids"
  aws ec2 terminate-instances --instance-ids $instance_ids
  aws ec2 wait instance-terminated --instance-ids $instance_ids
  echo "Termination complete for instances: $instance_ids"
}

terminate_instances "$DEPLOY_ENV"

# 3. Delete EC2 Volumes
echo "Deleting EC2 Volumes..."
volume_ids=$(aws ec2 describe-volumes \
  --query "Volumes[?Tags[?Key=='deploy_env' && Value=='${DEPLOY_ENV}']].VolumeId" \
  --output text)

if [ -n "$volume_ids" ]; then
  for volume_id in $volume_ids; do
    echo "Deleting volume: $volume_id"
    aws ec2 delete-volume --volume-id "$volume_id"
    if [ $? -eq 0 ]; then
      echo "Successfully deleted volume: $volume_id"
    else
      echo "[ERROR] Failed to delete volume: $volume_id"
    fi
  done
else
  echo "No volumes found with deploy_env=${DEPLOY_ENV}"
fi

## 4. Delete Security Groups and Network Interfaces
delete_network_interfaces() {
  sg_id=$1
  network_interfaces=$(aws ec2 describe-network-interfaces \
    --filters "Name=group-id,Values=$sg_id" --query "NetworkInterfaces[].NetworkInterfaceId" --output text)

  if [ -n "$network_interfaces" ]; then
    for nic in $network_interfaces; do
      attachment_id=$(aws ec2 describe-network-interfaces \
        --network-interface-ids "$nic" --query "NetworkInterfaces[0].Attachment.AttachmentId" --output text 2>/dev/null)

      if [ "$attachment_id" != "None" ]; then
        echo "Detaching network interface: $nic"
        aws ec2 detach-network-interface --attachment-id "$attachment_id"
      fi

      echo "Deleting network interface: $nic"
      aws ec2 delete-network-interface --network-interface-id "$nic"
    done
  fi
}

delete_security_group() {
  sg_id=$1
  delete_network_interfaces "$sg_id"
  echo "Deleting security group: $sg_id"
  aws ec2 delete-security-group --group-id "$sg_id"
}

echo "Deleting Security Groups..."
security_group_ids=$(aws ec2 describe-security-groups \
  --query "SecurityGroups[?contains(GroupName, '${DEPLOY_ENV}')].GroupId" --output text)

if [ -n "$security_group_ids" ]; then
  for sg_id in $security_group_ids; do
    echo $sg_id
    delete_security_group "$sg_id"
  done
else
  echo "No security groups found for ${DEPLOY_ENV}"
fi
#
# 5. Delete EC2 Key Pairs
echo "Deleting EC2 Key Pairs..."
aws ec2 describe-key-pairs --query "KeyPairs[?contains(KeyName, '${DEPLOY_ENV}')].KeyName" --output text | \
  xargs -I {} aws ec2 delete-key-pair --key-name "{}"

echo "Cleanup complete for resources associated with ${DEPLOY_ENV}!"

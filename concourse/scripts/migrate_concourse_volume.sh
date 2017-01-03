#!/usr/bin/env bash

set -e -u

AWS_REGION=eu-west-1
BOSH_INIT_CONCOURSE_STATE="s3://gds-paas-${DEPLOY_ENV}-state/concourse-manifest-state.json"
SCRIPT_NAME=$0

build_aws_cli_tag_filter() {
  local pair
  local filter
  filter=""
  for pair in "$@"; do
    filter="${filter:+${filter} }Name=tag:${pair%:*},Values=${pair#*:}"
  done
  echo "${filter}"
}

find_all_instances_by_tags() {
  local tag_filter
  tag_filter="$(build_aws_cli_tag_filter "$@")"
  # shellcheck disable=SC2086
  aws ec2 describe-instances \
    --region "${AWS_REGION}" \
    --filters ${tag_filter} \
    --query 'Reservations[].Instances[].InstanceId' \
    --output text | xargs
}

terminate_instance() {
  local instance_id
  instance_id="${1}"
  aws ec2 terminate-instances \
    --region "${AWS_REGION}" \
    --instance-ids "${instance_id}" > /dev/null
}

stop_instance() {
  local instance_id
  instance_id="${1}"
  aws ec2 stop-instances \
    --region "${AWS_REGION}" \
    --instance-ids "${instance_id}" > /dev/null
}

start_instance() {
  local instance_id
  instance_id="${1}"
  aws ec2 start-instances \
    --region "${AWS_REGION}" \
    --instance-ids "${instance_id}" > /dev/null
}

get_instance_state() {
  local instance_id
  instance_id="${1}"
  aws ec2 describe-instances \
    --region "${AWS_REGION}" \
    --instance-ids "${instance_id}" \
    --query 'Reservations[].Instances[].State.Name' \
    --output text
}

wait_instance_state() {
  local instance_id
  local expected_state
  instance_id="${1}"
  expected_state="${2}"

  echo -n "Waiting ${instance_id} to be ${expected_state}..."
  while ! [ "$(get_instance_state "${instance_id}")" == "${expected_state}" ]; do
    echo -n .
    sleep 5
  done
  echo "Ok."
}


find_instance_disk_by_device_name() {
  local instance_id
  local device_name
  instance_id="${1}"
  device_name="${2}"
  aws ec2 describe-instances \
    --region "${AWS_REGION}" \
    --instance-ids "${instance_id}" \
    --query "Reservations[].Instances[].BlockDeviceMappings[?DeviceName==\`${device_name}\`].Ebs.VolumeId" \
    --output text
}

snapshot_volume() {
  local volume_id
  local description
  volume_id="${1}"
  description="${2}"

  aws ec2 create-snapshot \
    --region "${AWS_REGION}" \
    --volume-id "${volume_id}" \
    --description "${description}" \
    --query "SnapshotId" \
    --output text
}

get_snapshot_state() {
  local snapshot_id
  snapshot_id="${1}"
  aws ec2 describe-snapshots \
    --region "${AWS_REGION}" \
    --snapshot-id "${snapshot_id}" \
    --query 'Snapshots[].State' \
    --output text
}

delete_snapshot() {
  local snapshot_id
  snapshot_id="${1}"
  aws ec2 describe-snapshots \
    --region "${AWS_REGION}" \
    --snapshot-id "${snapshot_id}" > /dev/null
}

wait_snapshot_completed() {
  local snapshot_id
  snapshot_id="${1}"

  echo -n "Waiting ${snapshot_id} to be completed..."
  while ! [ "$(get_snapshot_state "${snapshot_id}")" == "completed" ]; do
    echo -n .
    sleep 5
  done
  echo "Ok."
}

create_volume_from_snapshot () {
  local snapshot_id
  local availability_zone
  snapshot_id="${1}"
  availability_zone="${2}"
  aws ec2 create-volume \
    --region "${AWS_REGION}" \
    --availability-zone "${availability_zone}" \
    --snapshot-id "${snapshot_id}" \
    --query 'VolumeId' \
    --output text
}

get_volume_state() {
  local volume_id
  volume_id="${1}"
  aws ec2 describe-volumes \
    --region "${AWS_REGION}" \
    --volume-ids "${volume_id}" \
    --query 'Volumes[].State' \
    --output text
}

detach_volume() {
  local volume_id
  volume_id="${1}"
  aws ec2 detach-volume \
    --region "${AWS_REGION}" \
    --volume-id "${volume_id}" > /dev/null
}

delete_volume() {
  local volume_id
  volume_id="${1}"
  aws ec2 delete-volume \
    --region "${AWS_REGION}" \
    --volume-id "${volume_id}" > /dev/null
}

attach_volume() {
  local volume_id
  local instance_id
  local device_name
  volume_id="${1}"
  instance_id="${2}"
  device_name="${3}"
  aws ec2 attach-volume \
    --region "${AWS_REGION}" \
    --volume-id "${volume_id}" \
    --instance-id "${instance_id}" \
    --device "${device_name}" > /dev/null
}

wait_volume_available() {
  local volume_id
  volume_id="${1}"

  echo -n "Waiting ${volume_id} to be available..."
  while ! [ "$(get_volume_state "${volume_id}")" == "available" ]; do
    echo -n .
    sleep 5
  done
  echo "Ok."
}

clone_volume_via_snapsot() {
  local volume_id
  volume_id="${1}"
  snapshot_id="$(snapshot_volume "${volume_id}" "${DEPLOY_ENV} bosh-init concourse persistent disk")"
  echo "Created snapshot ${snapshot_id}"
  wait_snapshot_completed "${snapshot_id}"

  new_volume_id="$(create_volume_from_snapshot "${snapshot_id}" "${AWS_REGION}a")" # Hardcoded AZ
  wait_volume_available "${new_volume_id}"

  echo "Deleting snapshot ${snapshot_id}"
  delete_snapshot "${snapshot_id}"

  echo "${new_volume_id}"
}

check_concourse_bosh_init_state () {
  aws s3 ls \
    --region "${AWS_REGION}" \
    "${BOSH_INIT_CONCOURSE_STATE}" > /dev/null
}

get_concourse_bosh_init_state () {
  aws s3 cp \
    --region "${AWS_REGION}" \
    "${BOSH_INIT_CONCOURSE_STATE}" -
}

get_concourse_bosh_init_state_instance_id () {
  get_concourse_bosh_init_state | jq -r '.current_vm_cid'
}

get_concourse_bosh_init_state_volume_id () {
  get_concourse_bosh_init_state | jq -r '.disks[0].cid'
}


##########################################################################
stop_old_concourse() {
  if ! check_concourse_bosh_init_state; then
    echo "Cannot find a old bosh-init concourse state file, skipping"
    exit 0
  fi

  origin_concourse_instance_id="$(get_concourse_bosh_init_state_instance_id)"
  echo "bosh-init state origin concourse instance ID: ${origin_concourse_instance_id}"

  origin_concourse_volume_id="$(get_concourse_bosh_init_state_volume_id)"
  echo "bosh-init state persistent volume: ${origin_concourse_volume_id}"

  found_origin_concourse_instance_id="$(find_all_instances_by_tags "deployment:${DEPLOY_ENV}" job:concourse index:0 director:bosh-init)"

  if [ "${found_origin_concourse_instance_id}" ] && [ "$(get_instance_state "${found_origin_concourse_instance_id}")" != "terminated" ]; then
    echo "Found existing concourse instance ID: ${found_origin_concourse_instance_id}"
    found_origin_concourse_volume_id="$(find_instance_disk_by_device_name "${found_origin_concourse_instance_id}" "/dev/sdf")"
    echo "Found existing persistent volume (/dev/sdf): ${found_origin_concourse_instance_id}"

    if [ "${origin_concourse_instance_id}" != "${found_origin_concourse_instance_id}" ] || \
        [ "${origin_concourse_volume_id}" != "${found_origin_concourse_volume_id}" ]; then
        echo "Error: Instance ID or Volume ID in the state does not match with ones running."
        echo "State file: ${BOSH_INIT_CONCOURSE_STATE}"
        echo "State ids: ${origin_concourse_instance_id} ${origin_concourse_volume_id}"
        echo "Running ids: ${found_origin_concourse_instance_id} ${found_origin_concourse_volume_id}"
        exit 1
    fi

    echo "Terminating old concourse ${found_origin_concourse_instance_id}..."
    terminate_instance "${found_origin_concourse_instance_id}"
    wait_instance_state "${found_origin_concourse_instance_id}" "terminated"
  else
    echo "Unable to find a running bosh-init concourse. Has it been deleted already?"
  fi
}

attach_old_volume_to_new_concourse() {
  if ! check_concourse_bosh_init_state; then
    echo "Cannot find a old bosh-init concourse state file, skipping"
    exit 0
  fi

  origin_concourse_instance_id="$(get_concourse_bosh_init_state_instance_id)"
  echo "bosh-init state origin concourse instance ID: ${origin_concourse_instance_id}"

  origin_concourse_volume_id="$(get_concourse_bosh_init_state_volume_id)"
  echo "bosh-init state persistent volume: ${origin_concourse_volume_id}"

  new_concourse_instance_id="$(find_all_instances_by_tags deployment:concourse job:concourse index:0 "director:${DEPLOY_ENV}")"
  echo "New concourse instance ID: ${new_concourse_instance_id}"


  new_concourse_volume_id="$(find_instance_disk_by_device_name "${new_concourse_instance_id}" "/dev/sdf")"
  if [ "${new_concourse_volume_id}" ]; then
    if [ "${new_concourse_volume_id}" == "${origin_concourse_volume_id}" ]; then
      echo "The new concourse already has attached the volume ${origin_concourse_volume_id}. No need to update."
    else
      echo "Found existing persistent volume in new concourse (/dev/sdf): ${new_concourse_volume_id}"

      echo "Stoping the new concourse instance ${new_concourse_instance_id}"
      stop_instance "${new_concourse_instance_id}"
      wait_instance_state "${new_concourse_instance_id}" "stopped"

      echo "Detaching and deleting volume ${new_concourse_volume_id} from new concourse"
      detach_volume "${new_concourse_volume_id}"
      wait_volume_available "${new_concourse_volume_id}"
      delete_volume "${new_concourse_volume_id}"

      echo "Attaching ${origin_concourse_volume_id} to ${new_concourse_instance_id} as /dev/sdf"
      attach_volume "${origin_concourse_volume_id}" "${new_concourse_instance_id}" "/dev/sdf"
    fi
  fi

  echo "Starting again the new concourse instance ${new_concourse_instance_id}"
  start_instance "${new_concourse_instance_id}"
  wait_instance_state "${new_concourse_instance_id}" "running"

  # TODO: Check if we need to do a monit restart all, not sure if it really starts :-m
}

update_db_in_bosh_db() {
  origin_concourse_volume_id="$(get_concourse_bosh_init_state_volume_id)"
  echo "bosh-init state persistent volume: ${origin_concourse_volume_id}"

  bosh_db_address=$(aws s3 cp "s3://gds-paas-${DEPLOY_ENV}-state/bosh.tfstate" - | jq -r '.modules[0].outputs.bosh_db_address.value')
  bosh_db_password=$(aws s3 cp "s3://gds-paas-${DEPLOY_ENV}-state/bosh-secrets.yml" - | awk '/bosh_postgres_password/ { print $2 }')

  # We must use a SSH tunnel to be able to connect to the RDS db via concourse
  (
  cd "$(dirname "${SCRIPT_NAME}")/../.."
  make dev tunnel TUNNEL="5432:${bosh_db_address}:5432"
  )

  bosh_db_url="postgresql://dbadmin:${bosh_db_password}@localhost:5432/bosh"

  echo "Current volume disk associated in Bosh RDS:"
  psql "${bosh_db_url}" -c "
    select deployments.name, instances.job, instances.index, disk_cid
    from instances, deployments, persistent_disks
    where instances.deployment_id = deployments.id
      and deployments.name = 'concourse'
      and persistent_disks.instance_id = instances.id
      and instances.job = 'concourse'
      and instances.index=0;
  "

  echo "Updating volume:"
  psql "${bosh_db_url}" -c "
    update persistent_disks set disk_cid = '${origin_concourse_volume_id}'
    from instances, deployments
    where instances.deployment_id = deployments.id
      and deployments.name = 'concourse'
      and persistent_disks.instance_id = instances.id
      and instances.job = 'concourse'
      and instances.index=0;
    "

  disk_cid=$(psql "${bosh_db_url}" -ztA -c "
    select disk_cid
    from instances, deployments, persistent_disks
    where instances.deployment_id = deployments.id
      and deployments.name = 'concourse'
      and persistent_disks.instance_id = instances.id
      and instances.job = 'concourse'
      and instances.index=0;
  ")

  (
  cd "$(dirname "${SCRIPT_NAME}")/../.."
  make dev stop-tunnel
  )

  if [ "${origin_concourse_volume_id}" == "${disk_cid}" ]; then
    echo "Bosh RDS DB updated correctly"
  else
    echo "Error, Bosh RDS DB is not updated properly. Current disk_cid=${disk_cid}, expected ${origin_concourse_volume_id}"
  fi
}

case "${1:-}" in
  step1)
    stop_old_concourse
  ;;
  step2)
    attach_old_volume_to_new_concourse
    update_db_in_bosh_db
  ;;
  *)
    echo "Usage $0 <step1|step2>"
    exit 0
  ;;
esac





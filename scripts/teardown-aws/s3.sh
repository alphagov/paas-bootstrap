#!/bin/bash

source scripts/teardown-aws/logging-and-sanitisation.sh

# Set the prefix to identify resources associated with "dev02"
RESOURCE_PREFIX=${DEPLOY_ENV}

# Function to delete a single S3 bucket (empties and deletes in one step)
delete_bucket() {
  local bucket_name=$1

  # Trim whitespace from the bucket name
  bucket_name=$(echo "$bucket_name" | xargs)

  if [ -n "$bucket_name" ]; then
    echo "Deleting bucket and all contents: $bucket_name"

    # Empty and delete the bucket with minimal feedback
    aws s3 rb "s3://$bucket_name" --force >/dev/null 2>&1 || {
      echo "Failed to delete bucket: $bucket_name"
    }
  else
    echo "Bucket name is empty, skipping..."
  fi
}

# Function to delete all S3 buckets matching the RESOURCE_PREFIX
delete_s3_buckets() {
  echo "Finding and deleting S3 Buckets with prefix: '$RESOURCE_PREFIX'..."

  # List all S3 buckets matching the RESOURCE_PREFIX
  bucket_names=$(aws s3api list-buckets \
    --query "Buckets[?contains(Name, \`$RESOURCE_PREFIX\`)].Name" \
    --output text)

  # Iterate through each bucket name
  for bucket_name in $bucket_names; do
    delete_bucket "$bucket_name"
  done
}

# Run the delete S3 buckets function
delete_s3_buckets

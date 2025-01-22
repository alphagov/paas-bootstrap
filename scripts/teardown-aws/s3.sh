#!/bin/bash

source scripts/teardown-aws/logging-and-sanitisation.sh

# Set the prefix to identify resources associated with "dev02"
RESOURCE_PREFIX=${DEPLOY_ENV}

# Delete S3 Buckets
echo "Deleting S3 Buckets..."
# Function to delete S3 buckets and their contents
delete_s3_buckets() {
  echo "Deleting S3 Buckets..."

  # List all S3 buckets matching the RESOURCE_PREFIX
  aws s3api list-buckets --query "Buckets[?starts_with(Name, \`$RESOURCE_PREFIX\`)].Name" --output text | \
  while read -r bucket_name; do
    if [ -n "$bucket_name" ]; then
      echo "Processing S3 Bucket: $bucket_name"

      # Empty the bucket before deletion
      echo "Deleting objects from bucket: $bucket_name"
      aws s3 rm "s3://$bucket_name" --recursive || echo "Failed to delete objects from bucket: $bucket_name"

      # Delete the bucket
      echo "Deleting bucket: $bucket_name"
      aws s3api delete-bucket --bucket "$bucket_name" || echo "Failed to delete bucket: $bucket_name"
    else
      echo "No buckets found matching the prefix: $RESOURCE_PREFIX"
    fi
  done
}

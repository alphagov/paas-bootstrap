#!/bin/bash

delete_s3_buckets() {
  echo "Deleting S3 Buckets..."

  # List all S3 buckets matching the RESOURCE_PREFIX
  bucket_names=$(aws s3api list-buckets --query "Buckets[?starts_with(Name, '${DEPLOY_ENV}')].Name" --output text)

  if [ -z "$bucket_names" ]; then
    echo "No buckets found matching the prefix: $RESOURCE_PREFIX"
    return
  fi

  echo "Buckets to delete: $bucket_names"

  for bucket_name in $bucket_names; do
    if [ -n "$bucket_name" ]; then
      echo "Processing S3 Bucket: $bucket_name"

      # Empty the bucket before deletion
      echo "Deleting objects from bucket: $bucket_name"
      if aws s3 rm "s3://$bucket_name" --recursive; then
        echo "Objects deleted from bucket: $bucket_name"
      else
        echo "[ERROR] Failed to delete objects from bucket: $bucket_name"
        continue
      fi

      # Delete the bucket
      echo "Deleting bucket: $bucket_name"
      if aws s3api delete-bucket --bucket "$bucket_name"; then
        echo "Successfully deleted bucket: $bucket_name"
      else
        echo "[ERROR] Failed to delete bucket: $bucket_name"
      fi
    fi
  done
}

# Call the function
delete_s3_buckets

#!/bin/bash

# Helper function to log errors to standard error
log_error() {
  echo "[ERROR] $1" >&2
}

# Helper function to trim input and check if not empty, then execute the provided command
sanitize_and_execute() {
  while read -r resource; do
    sanitized_resource=$(echo "$resource" | tr -d '\r' | xargs)  # Remove control characters and trim whitespace
    if [ -n "$sanitized_resource" ]; then
      $1 "$sanitized_resource"
    else
      echo "Skipped invalid or empty resource."
    fi
  done
}
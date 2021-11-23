#!/bin/sh

BUCKET_NAME=$1
MAX_WAIT_TIME_SECONDS=$2
START=$(date +%s)

echo "Going to look in bucket $BUCKET_NAME for secrets"
echo ""

# Using paas trusted people as a sentinel value
if ! aws s3 ls "s3://${BUCKET_NAME}/paas-trusted-people/users.yml" > /dev/null 2>&1; then
    END=$(( START + MAX_WAIT_TIME_SECONDS))
    cat <<EOF
The secrets have not been uploaded to this environment's state bucket yet. Refer to the paas-bootstrap readme for how to upload them.

The pipeline will now wait until $(date -d @${END} +%H:%M:%S) to allow you to do that before moving on.
EOF

    while [ $END -gt "$(date +%s)" ]; do
        echo "Waiting.. ($(date +%H:%M:%S))"
        sleep 5
        if  aws s3 ls "s3://${BUCKET_NAME}/paas-trusted-people/users.yml" > /dev/null 2>&1; then
          echo "Secrets have been found. Continuing."
          exit 0
        fi
    done
    echo "Secrets not found and time ran out. Exiting"
    exit 1
else
    echo "Secrets have been uploaded. Continuing."
fi

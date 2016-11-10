# Datadog

Datadog is enabled by default for non-development environments. When testing Datadog in a dev environment you must set `ENABLE_DATADOG=true` when configuring the pipelines. The pipelines are configured using `make dev bootstrap`.

## Credentials

When setting up an environment the Datadog credentials need to be decrypted and pushed into the S3 state bucket as they are required during pipeline runs. Each environment (dev, ci, staging, and prod) has its own set of Application and API credentials in the PaaS credential store.

### Requirements

* Make sure you have access to the PaaS credential store, this is required for Datadog credentials.
* Load the AWS credentials for the environment you are setting up datadog for. These are required as the Datadog secrets file is stored in an S3 bucket.

### Usage
```
make <ENV> upload-datadog-secrets
```


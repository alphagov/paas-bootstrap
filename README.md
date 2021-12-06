# paas-bootstrap

⚠️
When merging pull requests, use the [gds-cli](https://github.com/alphagov/gds-cli): `gds git merge-sign alphagov/paas-bootstrap PR_NUMBER`
⚠️

GOV.UK Platform as a Service (PaaS) Bootstrap creates the foundations upon which the [paas-cf](http://github.com/alphagov/paas-cf) repository can deploy Cloud Foundry and the rest of the GOV.UK PaaS system components. The foundational components created by the bootstrap include:
* [Bosh](https://bosh.io/docs/)
  for provisioning and managing the virtual machines on which Concourse and Cloud Foundry will run.
* [Concourse](https://concourse-ci.org/)
  for continuous integration and continuous deployment pipelines. The CloudFoundry deployment pipelines will run here.
* [AWS VPC](https://aws.amazon.com/vpc/)
  for isolating the AWS resources created by `paas-bootstrap` and `paas-cf`.
* [AWS RDS databases](https://aws.amazon.com/rds/)
  for storing the state of Bosh and Concourse
* [Load balancers](https://aws.amazon.com/elasticloadbalancing/) and [TLS certificates](https://aws.amazon.com/certificate-manager/)
* [Load balancers](https://aws.amazon.com/elasticloadbalancing/) and [TLS certificates](https://aws.amazon.com/certificate-manager/)
  for providing secure ingress to Bosh and Concourse

It does not include the AWS IAM roles which are assumed by different system components. Those are created in the account-wide terraform (private repository).

## How does the bootstrap work?
`paas-bootstrap` is designed to solve the bootstrap problem. In our context: how do you deploy the software needed to deploy the rest of the system?

`paas-bootstrap` solves this by deploying a minimal version of Concourse ("Concourse Lite") onto an [AWS EC2](https://aws.amazon.com/ec2/) instance in the default AWS VPC, using [Hashicorp Vagrant](https://www.vagrantup.com/) and the [`vagrant-aws`](https://github.com/mitchellh/vagrant-aws) plugin, and is granted permission to create further AWS resources by the `concourse-lite` instance profile it assumes.

The `create-bosh-concourse` pipeline can be run on from Concourse Lite, which will create the persistent AWS resources, and configure the software running on top of them.

The persistent resources created will include a production configuration of Concourse, with the `create-bosh-concourse` pipeline.

## Deploying a new environment
`paas-bootstrap` can build the foundations for two types of environments:
* Cloud Foundry
* Build environments (for example, Docker containers or bosh releases)

The full bootstrap process below is only needed the first time an environment is deployed.

These instructions contain placeholders where the exact command may vary. This table explains the purpose of those placeholders

| Placeholder   | Purpose                                                                                                                                                                                                           |
| ------------- | ------------------------------------------|
| `$ACCOUNT`    | The AWS account being targeted (for example, `dev`, `staging`)|
| `$ENV` | <p>The name of the environment being targeted. In the case of short-lived development environments, this should have a value of `dev`, and the specific environment is set by the `DEPLOY_ENV` environment variable (max 8 chars).</p> <p>Do not use the same `DEPLOY_ENV` value for both types of bootstraps, because that will cause resource allocation conflicts and things will break</p>|

### Pre-requisites

- [ ] Make
- [ ] [GDS CLI](https://github.com/alphagov/gds-cli)
- [ ] [jq](https://github.com/stedolan/jq)
- [ ] Access to `paas-credentials` (private repository) and tools installed
- [ ] Connection to the GDS VPN
- [ ] Permission to assume the `Admin` role of the relevant AWS account (dev, CI, staging, production)
- [ ] `AWS_DEFAULT_REGION` environment set to the desired region for the environment
- [ ] [Github OAuth application credentials](https://docs.github.com/en/developers/apps/building-oauth-apps/creating-an-oauth-app).
  If you're deploying a production/staging/shared dev environment (for example, dev01, dev02), the app should belong to the alphagov organisation, and the credentials should be added to `paas-credentials` <br />
  If you're deploying a short-lived environment (for example, for penetration testing), the credentials can be associated with your GitHub account. You can put them in your personal password store, and set the path to it using the `GITHUB_PASSWORD_STORE_DIR` environment variable

## Deploying the bootstrap for Cloud Foundry

1. Clone `paas-bootstrap` at the tip of the `main` branch
2. Launch Concourse Lite.
    ```
    gds aws paas-$ACCOUNT-admin -- make $ENV deployer-concourse bootstrap
    ```
3. Log in to Concourse List at http://127.0.0.1:8080/login using the credentials shown in the output from step 2
4. Run the `create-bosh-concourse` pipeline
5. When the pipeline reaches the `check-for-secrets` job, it will pause for up to an hour (checking every 10 seconds) to allow secrets to be uploaded:
    ```
    gds aws paas-$ACCOUNT-admin -- make $ENV upload-all-secrets
    ```

   Note: if you're deploying a short-lived environment (for example, for penetration testing), the GitHub OAuth credentials will need to come from your personal `pass` store, and the path to it will be given by the `GITHUB_PASSWORD_STORE_DIR` env var
    ```
    gds aws paas-$ACCOUNT-admin -- make $ENV upload-all-secrets GITHUB_PASSWORD_STORE_DIR=/path/to/store
    ```
6. Wait for the pipeline to finish (this could take up to a couple of hours)
7. The persistent Concourse is now created, and Concourse Lite can be killed by running the `self-terminate` pipeline.
8. In [the Google API Console](https://console.cloud.google.com/apis/credentials), add the following URIs as authorised redirect URIs to the relevant OAuth 2.0 client configurations. This must be done manually and cannot be automated. It is required for Google authentication.

   The value of the $SYSTEM_DOMAIN placeholder here can be found under the `SYSTEM_DNS_ZONE_NAME` variable in the `Makefile`

   Note: all development environments fall under the "dev" name

   | OAuth 2.0 Client Config       | URI                                                                       |
   | ----------------------------- | ------------------------------------------------------------------------- |
   | GOV.UK PaaS Operator - $ENV   | https://login.$SYSTEM_DOMAIN/login/callback/admin-google                  |
   | GOV.UK PaaS Operator - $ENV   | https://uaa.$SYSTEM_DOMAIN/login/callback/admin-google                    |
   | GOV.UK PaaS Operator - $ENV   | https://bosh-external.$SYSTEM_DOMAIN:8443/login/callback/admin-google     |
   | GOV.UK PaaS Operator - $ENV   | https://bosh-uaa-external.$SYSTEM_DOMAIN:8443/login/callback/admin-google |
   | GOV.UK PaaS - PaaS Admin $ENV | https://admin.$SYSTEM_DOMAIN/my-account/use-google-sso/callback           |
   | GOV.UK PaaS $ENV Operator Grafana | https://grafana-1.$SYSTEM_DOMAIN |

## Deploying the bootstrap for build environments
1. Clone `paas-bootstrap` at the tip of the `main` branch
2. Launch Concourse Lite.
    ```
    gds aws paas-$ACCOUNT-admin -- make $ENV build-concourse bootstrap
    ```
3. Log in to Concourse List at http://127.0.0.1:8080/login using the credentials shown in the output from step 2
4. Run the `create-bosh-concourse` pipeline
5. When the pipeline reaches the `check-for-secrets` job, it will pause for up to an hour (checking every 10 seconds) to allow secrets to be uploaded:
    ```
    gds aws paas-$ACCOUNT-admin -- make $ENV upload-all-secrets
    ```
   Note: if you're deploying a short-lived environment (for example, for penetration testing), the GitHub OAuth credentials will need to come from your personal `pass` store, and the path to it will be given by the `GITHUB_PASSWORD_STORE_DIR` env var
    ```
    gds aws paas-$ACCOUNT-admin -- make $ENV upload-all-secrets GITHUB_PASSWORD_STORE_DIR=/path/to/store
    ```    
6. Wait for the pipeline to finish (this could take up to a couple of hours)
7. The persistent Concourse is now created, and Concourse Lite can be killed by running the `self-terminate` pipeline.

## Accessing a deployed bootstrap
Once deployed, Concourse can be accessed from the URLs below. By default, authentication with GitHub is enabled.

| Environment type | Environment name | URL |
| ---------------- | ---------------- | --- |
| Dev | Unique name | https://deployer.$NAME.dev.cloudpipeline.digital/ |
| Dev | Dev[0-9]+ | https://deployer.dev$NUMBER.dev.cloudpipeline.digital/ |
| Staging | `stg-lon` | https://deployer.london.staging.cloudpipeline.digital/ |
| CI | `build` | https://concourse.build.ci.cloudpipeline.digital/ |
| Production | `prod` | https://deployer.cloud.service.gov.uk/ |
| Production | `prod-lon` | https://deployer.london.cloud.service.gov.uk/ |

Non-development URLs are also accessible using the `gds paas open` command.

## Configuration options
`paas-bootstrap` has many configuration options exposed through the environment variables. Some useful ones are documented below. For the complete set, see the `Makefile`.

| Variable   | Purpose | Default value |
| ---------- | ------- | ------------- |
| `DEPLOY_ENV` | Development environments only, excluding dev01, dev02 etc. Sets the name of the environment | Set per environment |
| `GITHUB_PASSWORD_STORE_DIR` | Sets the path to a [`pass`](https://www.passwordstore.org/) store where Github credentials can be found. Used in `make upload-github-oauth` |  `~/.paas-pass`|
| `GOOGLE_PASSWORD_STORE_DIR` | Sets the path to a [`pass`](https://www.passwordstore.org/) store where Google credentials can be found. Used in `make upload-google-oauth`|  `~/.paas-pass`|
|`ENABLE_GITHUB` | Enables Github authentication for Concourse | `true` |

# paas-bootstrap

This repository contains [Concourse][] pipelines and related [Terraform][]
and [BOSH][] manifests that allow provisioning of a VPC with an instance of
Bosh and an instance of Concourse. It provides a generic starting point for
any kind of deployment environment.

[Concourse]: http://concourse.ci/
[Terraform]: https://terraform.io/
[BOSH]: https://bosh.io/

## Concourse Lite

This runs outside an environment and is responsible for creating and
destroying a VPC containing Bosh and Concourse.
You don't need to keep this running once Concourse is deployed,
and you can create it again when Concourse needs to be modified
or destroyed.

### Prerequisites

In order to use this repository you will need:

* Predefined [IAM instance profiles](http://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_switch-role-ec2_instance-profiles.html) that will be assigned to Concourse-lite, BOSH and Concourse. See below for details.

* [AWS Command Line tool (`awscli`)](https://aws.amazon.com/cli/). You can
install it using [any of the official methods](http://docs.aws.amazon.com/cli/latest/userguide/installing.html)
or by using [`virtualenv`](https://virtualenv.pypa.io/en/latest/) and pip `pip install -r requirements.txt`

* a recent version of [Vagrant installed][]. The exact version
requirements are listed in the [`Vagrantfile`](vagrant/Vagrantfile).

[Vagrant installed]: https://docs.vagrantup.com/v2/installation/index.html

Install the AWS plugin for Vagrant:

```
vagrant plugin install vagrant-aws
```

* provide AWS access keys as environment variables:

```
export AWS_ACCESS_KEY_ID=XXXXXXXXXX
export AWS_SECRET_ACCESS_KEY=YYYYYYYYYY
```
And optionally:

```
export AWS_DEFAULT_REGION=eu-west-1
```

The access keys are only required to spin up *Concourse Lite*. From
that point on they won't be required (except by manual actions) as all the
pipelines will use [instance profiles][] to make calls to AWS. The policies for
these are defined in the repo [aws-account-wide-terraform][]
(not public because it also contains state files).

[instance profiles]: http://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_switch-role-ec2_instance-profiles.html
[aws-account-wide-terraform]: https://github.gds/government-paas/aws-account-wide-terraform

* Declare your environment name using the variable DEPLOY_ENV.

```
$ export DEPLOY_ENV=environment-name
```

### Deploy

Create Concourse Lite with `make`. There are targets to select the target AWS account, and to select the profiles to apply. For instance for a DEV build concourse bootstrap:

```
make dev build-concourse bootstrap
```

`make help` will show all available options.

To deploy a concourse with custom profiles, it's necessary to set corresponding ENV vars. eg:
```
BOSH_INSTANCE_PROFILE=bosh-director-foo CONCOURSE_INSTANCE_PROFILE=concourse-foo make dev bootstrap
```

NB: This will [auto-delete overnight](#overnight-deletion-of-environments)
by default.

An SSH tunnel is created so that you can access it securely. The deploy
script can be re-run to update the pipelines or set up the tunnel again.

When complete it will output a URL and BasicAuth credentials that you can
use to login.

### Destroy

Run the following script:

```
make dev bootstrap-destroy
```

## Deployment

### Prerequisites

You will need a working [Concourse Lite](#concourse-lite).

### Deploy

Run the `create` pipeline from your *Concourse Lite*.

When complete you can access the UI from a browser with the same credentials as
your *Concourse Lite* on the following URL:

```
https://concourse.${DEPLOY_ENV}.dev.cloudpipeline.digital/
```

### Destroy

Run the `destroy` pipeline from your *Concourse Lite*.


# Additional notes

## Optionally override the branch used by pipelines

All of the pipeline scripts (including `vagrant/deploy.sh`) honour a
`BRANCH` environment variable which allows you to override the git branch
used within the pipeline. This is useful for development and code review:

```
BRANCH=$(git rev-parse --abbrev-ref HEAD) make dev pipelines
```

## Sharing your Bootstrap Concourse

If you need to share access to your *Bootstrap Concourse* with a colleague
then you will need to reproduce some of the work that Vagrant does.

Add their SSH public key:

```
cd vagrant
echo "ssh-rsa AAAA... user" | \
   vagrant ssh -- tee -a .ssh/authorized_keys
```

Learn the public IP of your *Bootstrap Concourse* run:

```
cd vagrant
vagrant ssh-config
```

They will then need to manually create the SSH tunnel that is normally
handled by `vagrant/deploy.sh`:

```
ssh ubuntu@<bootstrap_concourse_ip> -L 8080:127.0.0.1:8080 -fN
```

## Concourse credentials

By default, the environment setup script generates the concourse ATC password
for the admin user, based on the AWS credentials, the environment name and the
application name. If the `CONCOURSE_ATC_PASSWORD` environment variable is set,
this will be used instead. These credentials are output by all of the pipeline
deployment tasks.

These credentials will also be used by Concourse.

If necessary, the concourse password can be found in the `basic_auth_password`
property of `concourse-manifest.yml` in the state bucket.

You can also learn the credentials from the `atc` process arguments:

 1. SSH to the Concourse server:
    * For *Concourse Lite*: `cd vagrant && vagrant ssh`
    * [For *Concourse*](#ssh-to-concourse-and-tunnel)
 2. Get the password from `atc` arguments: `ps -fea | sed -n 's/.*--basic-auth[-]password \([^ ]*\).*/\1/p'`

## Overnight deletion of environments

In order to avoid unnecessary costs in AWS, there is some logic to
stop environments and VMs at night:

 * **Concourse Lite**: The `self-terminate` pipeline
   will be triggered every night to terminate *Concourse Lite*.

To prevent this from happening, you can simply pause the
pipelines or its resources or jobs.

Note that the *Concourse* and *BOSH* VMs will be kept running.

## aws-cli

You might need [aws-cli][] installed on your machine to debug a deployment.
You can install it using [Homebrew][] or a [variety of other methods][]. You
should provide [access keys using environment variables][] instead of
providing them to the interactive configure command.

[aws-cli]: https://aws.amazon.com/cli/
[Homebrew]: http://brew.sh/
[variety of other methods]: http://docs.aws.amazon.com/cli/latest/userguide/installing.html
[access keys using environment variables]: http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html#cli-environment

## SSH to concourse and tunnel
You can ssh to Concourse using the command: `make <env> ssh_concourse`
This will automatically get the right key and log you in as vcap user.

You can open an SSH tunnel to any TCP socket in the VPC with the command:
`make <env> tunnel TUNNEL=<local_port>:<remote_host>:<remote_port>`

Stop the tunnel with: `make <env> stop-tunnel`

## Other useful commands
Type `make` to get the list of all available commands.

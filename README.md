# paas-bootstrap

This repository contains [Concourse][] pipelines and related [Terraform][]
and [BOSH][] manifests that allow provisioning of a VPC with an instance of
Bosh and an instance of Concourse. It provides a generic starting point for
any kind of deployment environment.

[Concourse]: http://concourse.ci/
[Terraform]: https://terraform.io/
[BOSH]: https://bosh.io/

## Concourse Lite

Concourse Lite is responsible for bootstrapping a full Bosh and Concourse 
environment ([paas-cf][]). First it creates a Vagrant instance running on AWS.
Second this Vagrant instance is used to provision the full environment.

You don't need to keep this running once Concourse is deployed,
and you can create it again when Concourse needs to be modified
or destroyed.

[paas-cf]: https://github.com/alphagov/paas-cf

### Prerequisites

In order to use this repository you will need:

* Predefined [IAM instance profiles](http://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_switch-role-ec2_instance-profiles.html) that will be assigned to Concourse-lite, BOSH and Concourse. See below for details.

* [AWS Command Line tool (`awscli`)](https://aws.amazon.com/cli/). You can
install it using [any of the official methods](http://docs.aws.amazon.com/cli/latest/userguide/installing.html)
or by using [`virtualenv`](https://virtualenv.pypa.io/en/latest/) and pip `pip install -r requirements.txt`

* a recent version of [Vagrant installed][]. The exact version
requirements are listed in the [`Vagrantfile`](vagrant/Vagrantfile).

* a recent version of [jq](https://stedolan.github.io/jq/). 

[Vagrant installed]: https://docs.vagrantup.com/v2/installation/index.html

Install the AWS plugin for Vagrant:

```
vagrant plugin install vagrant-aws
```

* provide AWS access keys as environment variables:

```
export AWS_ACCESS_KEY_ID=XXXXXXXXXX
export AWS_SECRET_ACCESS_KEY=YYYYYYYYYY
export AWS_SESSION_TOKEN=ZZZZZZZZZZ # if using STS
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
[aws-account-wide-terraform]: https://github.digital.cabinet-office.gov.uk/government-paas/aws-account-wide-terraform

* Declare your environment name using the variable DEPLOY_ENV.

```
$ export DEPLOY_ENV=environment-name
```

If setting up a development environment you will be creating both a build and deployer Concourse environment. These will need separate names to avoid conflict. A pragmatic suggestion if your name is 'Dan Carley' is to have a build environment of `dcarleybuild` and a deploy environment of `dcarley`. At the time of writing the maximum length of a name is 12.

### Deploy

Create Concourse Lite with `make`. There are targets to select the target AWS account, and to select the profiles to apply. For instance for a DEV build concourse bootstrap:

```
make dev build-concourse bootstrap
```

Or a DEV deployer concourse bootstrap:

```
make dev deployer-concourse bootstrap
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

## Environment Deployment

### Prerequisites

You will need a working [Concourse Lite](#concourse-lite).

### Deploy

Run the `create` pipeline from your *Concourse Lite*.

When complete, you can access the new Concourse from your browser. The URL
and credentials can be found from:

```
make dev <profile>-concourse showenv
```

Login credentials can be shown by `make <env> showenv`.

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

## Concourse Lite credentials

By default, the Concourse Lite ATC password is generated, based on a hash of AWS UserId.
If the `CONCOURSE_ATC_PASSWORD` environment variable is set, this will be used instead.
It's safe to deterministically generate the password since Concourse Lite is only accessible via an ssh tunnel.

You can print the password with `make <env> showenv`

## Concourse credentials

The Concourse ATC password is randomly generated by the secret generator.
Once generated, it is stored in the s3 state bucket.

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

## Known caveats

### Fly version

Current mechanism of updating fly binary only checks if the date of your local
binary is older than one on the server. If you have been using previous fly
version recently, it won't get updated. In that case, delete the binary in /bin
directory and most recent one will be downloaded next time you run the scripts.

### SSH tunnel

The startup of docker compose is a bit non-deterministic. It needs to download
containers and start them. By default, we give it 180s timeout to do that. Most
of the times this will be long enough for concourse to start. But sometimes it
can happen that this is not long enough. In that case, re-run your makefile
action again. The scripts will attempt to connect to concourse again and if
succeeded, will continue with the script and upload the pipelines to concourse.

### Grafana/graphite metrics note
Bosh server metrics are shipped under 'collectd' name instead of 'bosh'.
This is because we use bosh-init to deploy bosh and it populates spec.name
differently than BOSH. We accept this as otherwise we'd have to introduce
a separate collectd config just for bosh or make the config composable.

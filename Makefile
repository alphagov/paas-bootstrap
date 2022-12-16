.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

DEPLOY_ENV_MAX_LENGTH=8
DEPLOY_ENV_VALID_LENGTH=$(shell if [ $$(printf "%s" $(DEPLOY_ENV) | wc -c) -gt $(DEPLOY_ENV_MAX_LENGTH) ]; then echo ""; else echo "OK"; fi)
DEPLOY_ENV_VALID_CHARS=$(shell if echo $(DEPLOY_ENV) | grep -q '^[a-zA-Z0-9-]*$$'; then echo "OK"; else echo ""; fi)
YAMLLINT=yamllint
SHELLCHECK=shellcheck
VAGRANT_SSH_KEY_NAME=${DEPLOY_ENV}-vagrant-bootstrap-concourse

.PHONY: check-env-vars
check-env-vars:
	$(if ${DEPLOY_ENV},,$(error Must pass DEPLOY_ENV=<name>))
	$(if ${DEPLOY_ENV_VALID_LENGTH},,$(error Sorry, DEPLOY_ENV ($(DEPLOY_ENV)) has a max length of $(DEPLOY_ENV_MAX_LENGTH), otherwise derived names will be too long))
	$(if ${DEPLOY_ENV_VALID_CHARS},,$(error Sorry, DEPLOY_ENV ($(DEPLOY_ENV)) must use only alphanumeric chars and hyphens, otherwise derived names will be malformatted))

.PHONY: test
test: spec lint_yaml lint_terraform lint_shellcheck lint_concourse lint_ruby ## Run linting tests

.PHONY: spec
spec:
	cd concourse/scripts &&\
		go get -t . &&\
		go test
	cd concourse &&\
		bundle exec rspec
	cd manifests/shared &&\
		bundle exec rspec
	cd manifests/bosh-manifest &&\
		bundle exec rspec
	cd manifests/runtime-config &&\
		bundle exec rspec
	cd manifests/concourse-manifest &&\
		bundle exec rspec
	cd vagrant &&\
		bundle exec rspec

lint_yaml:
	find . -name '*.yml' -not -path '*/vendor/*' | xargs $(YAMLLINT) -c yamllint.yml

GPG = $(shell command -v gpg2 || command -v gpg)

.PHONY: list_merge_keys
list_merge_keys: ## List all GPG keys allowed to sign merge commits.
	$(if $(GPG),,$(error "gpg2 or gpg not found in PATH"))
	@for key in $$(cat .gpg-id); do \
		printf "$${key}: "; \
		if [ "$$($(GPG) --version | awk 'NR==1 { split($$3,version,"."); print version[1]}')" = "2" ]; then \
			$(GPG) --list-keys --with-colons $$key 2> /dev/null | awk -F: '/^uid/ {found = 1; print $$10; exit} END {if (found != 1) {print "*** not found in local keychain ***"}}'; \
		else \
			$(GPG) --list-keys --with-colons $$key 2> /dev/null | awk -F: '/^pub/ {found = 1; print $$10} END {if (found != 1) {print "*** not found in local keychain ***"}}'; \
		fi;\
	done

.PHONY: update_merge_keys
update_merge_keys:
	ruby concourse/scripts/generate-public-key-vars.rb

lint_terraform:
	@./scripts/lint_terraform.sh

lint_shellcheck:
	find . -name '*.sh' -not -path '*/vendor/*' -a -not -path './manifests/bosh-manifest/upstream/*' | xargs $(SHELLCHECK)

lint_concourse:
	pipecleaner concourse/pipelines/* concourse/tasks/*

lint_ruby:
	bundle exec rubocop

.PHONY: globals
PASSWORD_STORE_DIR?=${HOME}/.paas-pass
globals:
	$(eval export PASSWORD_STORE_DIR=${PASSWORD_STORE_DIR})
	$(eval export GITHUB_PASSWORD_STORE_DIR?=${HOME}/.paas-pass)
	$(eval export GOOGLE_PASSWORD_STORE_DIR?=${HOME}/.paas-pass)
	@true

## Environments

.PHONY: dev
dev: globals ## Set Environment to DEV
	$(eval export SYSTEM_DNS_ZONE_NAME=$${DEPLOY_ENV}.dev.cloudpipeline.digital)
	$(eval export SYSTEM_DNS_ZONE_ID=Z1QGLFML8EG6G7)
	$(eval export APPS_DNS_ZONE_NAME=$${DEPLOY_ENV}.dev.cloudpipelineapps.digital)
	$(eval export APPS_DNS_ZONE_ID=Z3R6XFWUT4YZHB)
	$(eval export AWS_ACCOUNT=dev)
	$(eval export MAKEFILE_ENV_TARGET=dev)
	$(eval export ENABLE_DESTROY=true)
	$(eval export ENABLE_GITHUB ?= true)
	$(eval export CONCOURSE_AUTH_DURATION=48h)
	$(eval export SKIP_COMMIT_VERIFICATION=true)
	$(eval export AWS_DEFAULT_REGION ?= eu-west-1)
	$(eval export CYBER_PASSWORD_STORE_DIR?=${HOME}/.paas-pass)
	$(eval export CONCOURSE_INSTANCE_TYPE=c5a.xlarge)
	@true

.PHONY: $(filter-out dev%,$(MAKECMDGOALS))
dev%: dev
	$(eval export DEPLOY_ENV=$@)
	$(eval export SYSTEM_DNS_ZONE_NAME=${DEPLOY_ENV}.dev.cloudpipeline.digital)
	$(eval export APPS_DNS_ZONE_NAME=${DEPLOY_ENV}.dev.cloudpipelineapps.digital)
	@true


.PHONY: ci
ci: globals ## Set Environment to CI
	$(eval export SYSTEM_DNS_ZONE_NAME=${DEPLOY_ENV}.ci.cloudpipeline.digital)
	$(eval export SYSTEM_DNS_ZONE_ID=Z2PF4LCV9VR1MV)
	$(eval export AWS_ACCOUNT=ci)
	$(eval export MAKEFILE_ENV_TARGET=ci)
	$(eval export ENABLE_GITHUB=true)
	$(eval export CONCOURSE_AUTH_DURATION=18h)
	$(eval export AWS_DEFAULT_REGION ?= eu-west-1)
	$(eval export CYBER_PASSWORD_STORE_DIR?=${HOME}/.paas-pass)
	@true

.PHONY: stg-lon
stg-lon: globals ## Set Environment to stg-lon
	$(eval export DEPLOY_ENV=stg-lon)
	$(eval export SYSTEM_DNS_ZONE_NAME=london.staging.cloudpipeline.digital)
	$(eval export SYSTEM_DNS_ZONE_ID=ZPFAUK62IO6DS)
	$(eval export APPS_DNS_ZONE_NAME=london.staging.cloudpipelineapps.digital)
	$(eval export APPS_DNS_ZONE_ID=Z32JRRSU1CAFE8)
	$(eval export AWS_ACCOUNT=staging)
	$(eval export MAKEFILE_ENV_TARGET=stg-lon)
	$(eval export ENABLE_GITHUB=true)
	$(eval export CONCOURSE_AUTH_DURATION=18h)
	$(eval export AWS_DEFAULT_REGION=eu-west-2)
	$(eval export CYBER_PASSWORD_STORE_DIR?=${HOME}/.paas-pass-high)
	@true

.PHONY: prod
prod: globals ## Set Environment to Prod
	$(eval export DEPLOY_ENV=prod)
	$(eval export SYSTEM_DNS_ZONE_NAME=cloud.service.gov.uk)
	$(eval export SYSTEM_DNS_ZONE_ID=Z39UURGVWSYTHL)
	$(eval export APPS_DNS_ZONE_NAME=cloudapps.digital)
	$(eval export APPS_DNS_ZONE_ID=Z29K8LQNCFDZ1T)
	$(eval export AWS_ACCOUNT=prod)
	$(eval export MAKEFILE_ENV_TARGET=prod)
	$(eval export ENABLE_GITHUB=true)
	$(eval export CONCOURSE_AUTH_DURATION=18h)
	$(eval export AWS_DEFAULT_REGION=eu-west-1)
	$(eval export CYBER_PASSWORD_STORE_DIR?=${HOME}/.paas-pass-high)
	@true

.PHONY: prod-lon
prod-lon: globals ## Set Environment to prod-lon
	$(eval export DEPLOY_ENV=prod-lon)
	$(eval export SYSTEM_DNS_ZONE_NAME=london.cloud.service.gov.uk)
	$(eval export SYSTEM_DNS_ZONE_ID=Z39UURGVWSYTHL)
	$(eval export APPS_DNS_ZONE_NAME=london.cloudapps.digital)
	$(eval export APPS_DNS_ZONE_ID=Z29K8LQNCFDZ1T)
	$(eval export AWS_ACCOUNT=prod)
	$(eval export MAKEFILE_ENV_TARGET=prod-lon)
	$(eval export ENABLE_GITHUB=true)
	$(eval export CONCOURSE_AUTH_DURATION=18h)
	$(eval export AWS_DEFAULT_REGION=eu-west-2)
	$(eval export CYBER_PASSWORD_STORE_DIR?=${HOME}/.paas-pass-high)
	@true

## Concourse profiles

.PHONY: build-concourse
build-concourse: ## Setup profiles for deploying a build concourse
	$(if ${SYSTEM_DNS_ZONE_NAME},,$(error Must set SYSTEM_DNS_ZONE_NAME. This can be done with the relevant environment make target.))
	$(eval export BOSH_INSTANCE_PROFILE=bosh-director-build)
	$(eval export CONCOURSE_TYPE=build-concourse)
	$(eval export CONCOURSE_HOSTNAME=concourse)
	$(eval export CONCOURSE_INSTANCE_TYPE=c5a.xlarge)
	$(eval export CONCOURSE_INSTANCE_PROFILE=concourse-build)
	$(eval export CONCOURSE_WORKER_INSTANCES ?= 4)
	@true

.PHONY: deployer-concourse
deployer-concourse: ## Setup profiles for deploying a paas-cf deployer concourse
	$(if ${SYSTEM_DNS_ZONE_NAME},,$(error Must set SYSTEM_DNS_ZONE_NAME. This can be done with the relevant environment make target.))
	$(if ${APPS_DNS_ZONE_NAME},,$(error Must set APPS_DNS_ZONE_NAME. This can be done with the relevant environment make target.))
	$(eval export BOSH_INSTANCE_PROFILE=bosh-director-cf)
	$(eval export CONCOURSE_TYPE=deployer-concourse)
	$(eval export CONCOURSE_HOSTNAME=deployer)
	$(eval export CONCOURSE_INSTANCE_TYPE ?= m5.xlarge)
	$(eval export CONCOURSE_INSTANCE_PROFILE=deployer-concourse)
	$(eval export CONCOURSE_WORKER_INSTANCES ?= 1)
	@true

## Actions

.PHONY: current-branch
current-branch: ## Deploy current checked out branch
	$(eval export BRANCH=$(shell sh -c "git rev-parse --abbrev-ref HEAD"))
	@true

.PHONY: pipelines
pipelines: check-env-vars
	$(eval export TARGET_CONCOURSE=${CONCOURSE_TYPE})
	$(if ${TARGET_CONCOURSE},,$(error Must set CONCOURSE_TYPE=deployer-concourse|build-concourse. This can be done with the relevant make target.))
	$$("./concourse/scripts/environment.sh") && \
                ./concourse/scripts/pipelines.sh

.PHONY: bootstrap
bootstrap: check-env-vars ## Start bootstrap
	$(if ${BOSH_INSTANCE_PROFILE},,$(error Must pass BOSH_INSTANCE_PROFILE=<name>))
	$(if ${CONCOURSE_HOSTNAME},,$(error Must pass CONCOURSE_HOSTNAME=<name>))
	$(if ${CONCOURSE_INSTANCE_TYPE},,$(error Must pass CONCOURSE_INSTANCE_TYPE=<name>))
	$(if ${CONCOURSE_INSTANCE_PROFILE},,$(error Must pass CONCOURSE_INSTANCE_PROFILE=<name>))
	$(eval export VAGRANT_SSH_KEY_NAME=$(VAGRANT_SSH_KEY_NAME))
	$(eval export TARGET_CONCOURSE=bootstrap)
	vagrant/deploy.sh

.PHONY: bootstrap-destroy
bootstrap-destroy: check-env-vars ## Destroy bootstrap
	$(eval export VAGRANT_SSH_KEY_NAME=$(VAGRANT_SSH_KEY_NAME))
	$(eval export TARGET_CONCOURSE=bootstrap)
	./vagrant/destroy.sh

.PHONY: showenv
showenv: check-env-vars ## Display environment information
	$(eval export TARGET_CONCOURSE=bootstrap)
	@concourse/scripts/environment.sh
	@echo export CONCOURSE_IP=$$(aws ec2 describe-instances \
		--filters "Name=tag:deploy_env,Values=${DEPLOY_ENV}" 'Name=tag:instance_group,Values=concourse' \
		--query 'Reservations[].Instances[].PublicIpAddress' --output text)
	@echo export BOOTSTRAP_CONCOURSE_IP=$$(aws ec2 describe-instances \
		--filters 'Name=tag:Name,Values=*concourse' "Name=key-name,Values=${VAGRANT_SSH_KEY_NAME}" \
                --query 'Reservations[].Instances[].PublicIpAddress' --output text)

.PHONY: bosh-cli
bosh-cli: check-env-vars ## Run a local container with bosh targetted at the DEPLOY_ENV's director
	@./scripts/bosh-cli.sh

.PHONY: ssh_bosh
ssh_bosh: check-env-vars ## SSH to the bosh server
	@./scripts/ssh_bosh.sh

ssh_concourse: check-env-vars ## SSH to the concourse server. Set SSH_CMD to pass a command to execute.
	@./concourse/scripts/ssh.sh ssh ${SSH_CMD}

ssh_bootstrap_concourse: check-env-vars ## SSH to the bootstrap concourse server
	@cd vagrant ; vagrant ssh -- -i ../${VAGRANT_SSH_KEY_NAME}

tunnel: check-env-vars ## SSH tunnel to internal IPs
	$(if ${TUNNEL},,$(error Must pass TUNNEL=SRC_PORT:HOST:DST_PORT))
	@./concourse/scripts/ssh.sh tunnel ${TUNNEL}

stop-tunnel: check-env-vars ## Stop SSH tunnel
	@./concourse/scripts/ssh.sh tunnel stop

.PHONY: upload-all-secrets
upload-all-secrets: upload-github-oauth upload-google-oauth upload-cyber-tfvars upload-cyber-secrets upload-paas-trusted-people

.PHONY: upload-github-oauth
upload-github-oauth: check-env-vars ## Decrypt and upload github OAuth credentials to S3
	$(if ${MAKEFILE_ENV_TARGET},,$(error Must set MAKEFILE_ENV_TARGET))
	$(if ${GITHUB_PASSWORD_STORE_DIR},,$(error Must pass GITHUB_PASSWORD_STORE_DIR=<path_to_password_store>))
	$(if $(wildcard ${GITHUB_PASSWORD_STORE_DIR}),,$(error Password store ${GITHUB_PASSWORD_STORE_DIR} does not exist))
	@scripts/upload-secrets/manage-github-secrets.sh upload

.PHONY: upload-google-oauth
upload-google-oauth: check-env-vars ## Decrypt and upload google OAuth credentials to S3
	$(if ${MAKEFILE_ENV_TARGET},,$(error Must set MAKEFILE_ENV_TARGET))
	$(if ${GOOGLE_PASSWORD_STORE_DIR},,$(error Must pass GOOGLE_PASSWORD_STORE_DIR=<path_to_password_store>))
	$(if $(wildcard ${GOOGLE_PASSWORD_STORE_DIR}),,$(error Password store ${GOOGLE_PASSWORD_STORE_DIR} does not exist))
	@scripts/upload-secrets/upload-google-oauth-secrets.sh

.PHONY: upload-cyber-secrets
upload-cyber-secrets: check-env-vars ## Decrypt and upload cyber credentials to S3
	$(if ${MAKEFILE_ENV_TARGET},,$(error Must set MAKEFILE_ENV_TARGET))
	$(if ${CYBER_PASSWORD_STORE_DIR},,$(error Must pass CYBER_PASSWORD_STORE_DIR=<path_to_password_store>))
	$(if $(wildcard ${CYBER_PASSWORD_STORE_DIR}),,$(error Password store ${CYBER_PASSWORD_STORE_DIR} does not exist))
	@scripts/upload-secrets/upload-cyber-secrets.sh

.PHONY: upload-cyber-tfvars
upload-cyber-tfvars: check-env-vars ## Decrypt and upload cyber tfvars to S3
	$(if ${MAKEFILE_ENV_TARGET},,$(error Must set MAKEFILE_ENV_TARGET))
	$(if ${CYBER_PASSWORD_STORE_DIR},,$(error Must pass CYBER_PASSWORD_STORE_DIR=<path_to_password_store>))
	$(if $(wildcard ${CYBER_PASSWORD_STORE_DIR}),,$(error Password store ${CYBER_PASSWORD_STORE_DIR} does not exist))
	@scripts/upload-secrets/upload-cyber-tfvars.sh

.PHONY: upload-paas-trusted-people
upload-paas-trusted-people: check-env-vars
	@scripts/upload-secrets/upload-paas-trusted-people.sh

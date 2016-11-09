.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

DEPLOY_ENV_MAX_LENGTH=12
DEPLOY_ENV_VALID_LENGTH=$(shell if [ $$(printf "%s" $(DEPLOY_ENV) | wc -c) -gt $(DEPLOY_ENV_MAX_LENGTH) ]; then echo ""; else echo "OK"; fi)
DEPLOY_ENV_VALID_CHARS=$(shell if echo $(DEPLOY_ENV) | grep -q '^[a-zA-Z0-9-]*$$'; then echo "OK"; else echo ""; fi)
YAMLLINT=yamllint
SHELLCHECK=shellcheck

check-env-vars:
	$(if ${DEPLOY_ENV},,$(error Must pass DEPLOY_ENV=<name>))
	$(if ${DEPLOY_ENV_VALID_LENGTH},,$(error Sorry, DEPLOY_ENV ($(DEPLOY_ENV)) has a max length of $(DEPLOY_ENV_MAX_LENGTH), otherwise derived names will be too long))
	$(if ${DEPLOY_ENV_VALID_CHARS},,$(error Sorry, DEPLOY_ENV ($(DEPLOY_ENV)) must use only alphanumeric chars and hyphens, otherwise derived names will be malformatted))

.PHONY: test
test: spec lint_yaml lint_terraform lint_shellcheck lint_concourse lint_ruby ## Run linting tests

.PHONY: spec
spec:
	cd concourse/scripts &&\
		go test
	cd manifests/shared &&\
		bundle exec rspec
	cd manifests/bosh-manifest &&\
		bundle exec rspec
	cd manifests/concourse-manifest &&\
		bundle exec rspec

lint_yaml:
	find . -name '*.yml' -not -path '*/vendor/*' | xargs $(YAMLLINT) -c yamllint.yml

lint_terraform:
	$(eval export TF_VAR_system_dns_zone_name=service.com)
	$(eval export TF_VAR_apps_dns_zone_name=apps.com)
	find terraform -mindepth 1 -maxdepth 1 -type d -print0 | xargs -0 -n 1 -t terraform graph > /dev/null

lint_shellcheck:
	find . -name '*.sh' -not -path '*/vendor/*' | xargs $(SHELLCHECK)

lint_concourse:
	cd .. && SHELLCHECK_OPTS="-e SC1091,SC2034,SC2046,SC2086" python paas-bootstrap/concourse/scripts/pipecleaner.py paas-bootstrap/concourse/pipelines/*.yml

lint_ruby:
	bundle exec govuk-lint-ruby

.PHONY: globals
globals:
	$(eval export AWS_DEFAULT_REGION=eu-west-1)
	@true

.PHONY: dev
dev: globals check-env-vars ## Set Environment to DEV
	$(eval export SYSTEM_DNS_ZONE_NAME=${DEPLOY_ENV}.dev.cloudpipeline.digital)
	$(eval export AWS_ACCOUNT=dev)

.PHONY: ci
ci: globals check-env-vars ## Set Environment to CI
	$(eval export SYSTEM_DNS_ZONE_NAME=${DEPLOY_ENV}.ci.cloudpipeline.digital)
	$(eval export AWS_ACCOUNT=ci)

.PHONY: fly-login
fly-login: ## Do a fly login and sync
	$(eval export TARGET_CONCOURSE=deployer)
	$$("./concourse/scripts/environment.sh") && \
		./concourse/scripts/fly_sync_and_login.sh


.PHONY: bootstrap
bootstrap: ## Start bootstrap
	$(if ${BOSH_INSTANCE_PROFILE},,$(error Must pass BOSH_INSTANCE_PROFILE=<name>))
	$(if ${CONCOURSE_INSTANCE_PROFILE},,$(error Must pass CONCOURSE_INSTANCE_PROFILE=<name>))
	vagrant/deploy.sh

.PHONY: bootstrap-destroy
bootstrap-destroy: ## Destroy bootstrap
	./vagrant/destroy.sh

.PHONY: showenv
showenv: ## Display environment information
	$(eval export TARGET_CONCOURSE=deployer)
	@echo CONCOURSE_IP=$$(aws ec2 describe-instances \
		--filters 'Name=tag:Name,Values=concourse/*' "Name=key-name,Values=${DEPLOY_ENV}_concourse_key_pair" \
		--query 'Reservations[].Instances[].PublicIpAddress' --output text)
	@concourse/scripts/environment.sh

ssh_concourse: check-env-vars ## SSH to the concourse server
	@./concourse/scripts/ssh.sh

tunnel: check-env-vars ## SSH tunnel to internal IPs
	$(if ${TUNNEL},,$(error Must pass TUNNEL=SRC_PORT:HOST:DST_PORT))
	@./concourse/scripts/ssh.sh ${TUNNEL}

stop-tunnel: check-env-vars ## Stop SSH tunnel
	@./concourse/scripts/ssh.sh stop

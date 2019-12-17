.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: test
test: spec lint_yaml lint_terraform lint_shellcheck lint_concourse lint_ruby ## Run linting tests

.PHONY: spec
spec:
	cd concourse/scripts &&\
		go get -t -d . &&\
		go test
	cd concourse &&\
		bundle exec rspec
	cd manifests/shared &&\
		bundle exec rspec
	cd manifests/bosh-manifest &&\
		bundle exec rspec
	cd manifests/concourse-manifest &&\
		bundle exec rspec

lint_yaml:
	find . -name '*.yml' -not -path '*/vendor/*' | xargs $(YAMLLINT) -c yamllint.yml

lint_terraform:
	@./scripts/lint_terraform.sh

lint_shellcheck:
	find . -name '*.sh' -not -path '*/vendor/*' -a -not -path './manifests/bosh-manifest/upstream/*' | xargs $(SHELLCHECK)

lint_concourse:
	cd .. && SHELLCHECK_OPTS="-e SC1091" python paas-bootstrap/concourse/scripts/pipecleaner.py --fatal-warnings paas-bootstrap/concourse/pipelines/*.yml

lint_ruby:
	bundle exec govuk-lint-ruby

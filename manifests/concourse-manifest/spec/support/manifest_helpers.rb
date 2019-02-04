require 'singleton'
require 'open3'
require 'yaml'
require 'tempfile'

module ManifestHelpers
  SYSTEM_DNS_ZONE_NAME = 'example.com'.freeze

  class Cache
    include Singleton
    attr_accessor :manifest_with_defaults
    attr_accessor :manifest_with_github_auth
    attr_accessor :concourse_secrets_file
    attr_accessor :concourse_secrets_data
  end

  def manifest_with_defaults
    Cache.instance.manifest_with_defaults ||= render_manifest
  end

  def manifest_with_github_auth
    Cache.instance.manifest_with_github_auth ||= render_manifest(
      override_env: {
        'ENABLE_GITHUB' => 'true',
        'GITHUB_CLIENT_ID' => 'dummy_github_client_id',
        'GITHUB_CLIENT_SECRET' => 'dummy_github_client_secret',
      }
    )
  end

  def concourse_secrets_file
    Cache.instance.concourse_secrets_file ||= generate_concourse_secrets
    Cache.instance.concourse_secrets_file.path
  end

  def concourse_secrets_value(key)
    Cache.instance.concourse_secrets_data ||= YAML.load_file(concourse_secrets_file).fetch('secrets')
    Cache.instance.concourse_secrets_data.fetch(key)
  end

private

  def root
    Pathname(File.expand_path("../../../..", __dir__))
  end

  def fake_env_vars
    env = {}
    env["AWS_ACCOUNT"] = "dev"
    env["CONCOURSE_INSTANCE_TYPE"] = "t2.small"
    env["CONCOURSE_INSTANCE_PROFILE"] = "concourse-build"
    env["CONCOURSE_AUTH_DURATION"] = "5m"
    env["SYSTEM_DNS_ZONE_NAME"] = ManifestHelpers::SYSTEM_DNS_ZONE_NAME
    env["ENABLE_GITHUB"] = "false"
    env
  end

  def render_manifest(override_env: {})
    workdir = Pathname(Dir.mktmpdir('paas-bootstrap-test'))

    env = fake_env_vars.merge(override_env)
    env['PAAS_BOOTSTRAP_DIR'] = root.to_s
    env['WORKDIR'] = workdir.to_s

    copy_terraform_fixtures("#{workdir}/terraform-outputs", %w(vpc bosh concourse))
    generate_bosh_secrets_fixture("#{workdir}/bosh-secrets")
    FileUtils.mkdir("#{workdir}/concourse-secrets")
    FileUtils.cp(concourse_secrets_file, "#{workdir}/concourse-secrets/concourse-secrets.yml")

    output, error, status = Open3.capture3(
      env,
      root.join("manifests/concourse-manifest/scripts/generate-manifest.sh").to_s,
    )
    expect(status).to be_success, "generate_manifest.sh exited #{status.exitstatus}, stderr:\n#{error}"

    # Deep freeze the object so that it's safe to use across multiple examples
    # without risk of state leaking.
    deep_freeze(YAML.safe_load(output))
  ensure
    FileUtils.rm_rf(workdir)
  end

  def generate_concourse_secrets
    file = Tempfile.new(['test-concourse-secrets', '.yml'])
    output, error, status = Open3.capture3(File.expand_path("../../../scripts/generate-concourse-secrets.rb", __FILE__))
    unless status.success?
      raise "Error generating concourse-secrets, exit: #{status.exitstatus}, output:\n#{output}\n#{error}"
    end
    file.write(output)
    file.flush
    file.rewind
    file
  end

  def deep_freeze(object)
    case object
    when Hash
      object.each { |_k, v| deep_freeze(v) }
    when Array
      object.each { |v| deep_freeze(v) }
    end
    object.freeze
  end
end

RSpec.configuration.include ManifestHelpers

require 'singleton'
require 'open3'
require 'yaml'
require 'tempfile'

module ManifestHelpers
  SYSTEM_DNS_ZONE_NAME = 'example.com'.freeze

  class Cache
    include Singleton
    attr_accessor :manifest_with_defaults
    attr_accessor :bosh_secrets_file
    attr_accessor :bosh_secrets_data
  end

  def manifest_with_defaults
    Cache.instance.manifest_with_defaults ||= load_default_manifest
  end

  def bosh_secrets_file
    Cache.instance.bosh_secrets_file ||= generate_bosh_secrets
    Cache.instance.bosh_secrets_file.path
  end

  def bosh_secrets_value(key)
    Cache.instance.bosh_secrets_data ||= YAML.load_file(bosh_secrets_file).fetch('secrets')
    Cache.instance.bosh_secrets_data.fetch(key)
  end

  def self.deploy_env
    "spec"
  end

private

  def fake_env_vars
    ENV["BOSH_FQDN_EXTERNAL"] = "bosh-external.domain"
    ENV["BOSH_FQDN"] = "bosh.domain"
    ENV["AWS_ACCOUNT"] = "dev"
    ENV["BOSH_INSTANCE_PROFILE"] = "bosh-director-build"
    ENV["DATADOG_API_KEY"] = "abcd1234"
    ENV["DATADOG_APP_KEY"] = "abcd4321"
    ENV["ENABLE_DATADOG"] = "true"
    ENV["DEPLOY_ENV"] = ManifestHelpers.deploy_env
    ENV["SYSTEM_DNS_ZONE_NAME"] = ManifestHelpers::SYSTEM_DNS_ZONE_NAME
  end

  def load_default_manifest
    fake_env_vars
    output, error, status = Open3.capture3(
      [
        File.expand_path("../../../../shared/build_manifest.sh", __FILE__),
        File.expand_path("../../../bosh-manifest.yml", __FILE__),
        File.expand_path("../../../eu-west-1.yml", __FILE__),
        bosh_secrets_file,
        File.expand_path("../../fixtures/bosh-ssl-certificates.yml", __FILE__),
        File.expand_path("../../../../shared/spec/fixtures/bosh-terraform-outputs.yml", __FILE__),
        File.expand_path("../../../../shared/spec/fixtures/vpc-terraform-outputs.yml", __FILE__),
        File.expand_path("../../../../shared/addons/datadog-agent.yml", __FILE__),
        File.expand_path("../../../addons/datadog-agent-bosh-properties.yml", __FILE__),
      ].join(' ')
    )
    expect(status).to be_success, "build_manifest.sh exited #{status.exitstatus}, stderr:\n#{error}"

    # Deep freeze the object so that it's safe to use across multiple examples
    # without risk of state leaking.
    deep_freeze(YAML.safe_load(output))
  end

  def generate_bosh_secrets
    file = Tempfile.new(['test-bosh-secrets', '.yml'])
    output, error, status = Open3.capture3(File.expand_path("../../../scripts/generate-bosh-secrets.rb", __FILE__))
    unless status.success?
      raise "Error generating bosh-secrets, exit: #{status.exitstatus}, output:\n#{output}\n#{error}"
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

require 'singleton'
require 'open3'
require 'yaml'
require 'tempfile'

module ManifestHelpers
  SYSTEM_DNS_ZONE_NAME = 'example.com'.freeze

  class Cache
    include Singleton
    attr_accessor :manifest_with_defaults
    attr_accessor :concourse_secrets_file
    attr_accessor :concourse_secrets_data
  end

  def manifest_with_defaults
    Cache.instance.manifest_with_defaults ||= load_default_manifest
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

  def fake_env_vars
    ENV["AWS_ACCOUNT"] = "dev"
    ENV["CONCOURSE_INSTANCE_TYPE"] = "t2.small"
    ENV["CONCOURSE_INSTANCE_PROFILE"] = "concourse-build"
    ENV["CONCOURSE_AUTH_DURATION"] = "5m"
    ENV["SYSTEM_DNS_ZONE_NAME"] = ManifestHelpers::SYSTEM_DNS_ZONE_NAME
  end

  def load_default_manifest
    fake_env_vars
    output, error, status = Open3.capture3(
      [
        File.expand_path("../../../../shared/build_manifest.sh", __FILE__),
        File.expand_path("../../../concourse-base.yml", __FILE__),
        concourse_secrets_file,
        File.expand_path("../../../../shared/spec/fixtures/concourse-terraform-outputs.yml", __FILE__),
        File.expand_path("../../../../shared/spec/fixtures/bosh-terraform-outputs.yml", __FILE__),
        File.expand_path("../../../../shared/spec/fixtures/vpc-terraform-outputs.yml", __FILE__),
      ].join(' ')
    )
    expect(status).to be_success, "build_manifest.sh exited #{status.exitstatus}, stderr:\n#{error}"

    # Deep freeze the object so that it's safe to use across multiple examples
    # without risk of state leaking.
    deep_freeze(YAML.safe_load(output))
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

require 'open3'
require 'yaml'
require 'singleton'

module ManifestHelpers
  SYSTEM_DNS_ZONE_NAME = 'example.com'.freeze
  LOGIT_SYSLOG_ADDRESS = "logit-syslog-url.internal".freeze
  LOGIT_SYSLOG_PORT    = "6514".freeze
  LOGIT_CA_CERT        = "-----BEGIN CERTIFICATE-----\n01234\n-----END CERTIFICATE-----\n-----BEGIN CERTIFICATE-----\n56789\n-----END CERTIFICATE-----".freeze

  class Cache
    include Singleton
    attr_accessor :default_runtime_config
    attr_accessor :terraform_fixture
  end

  def default_runtime_config
    Cache.instance.default_runtime_config ||= load_runtime_config
  end

  def terraform_fixture(key)
    Cache.instance.terraform_fixture ||= load_terraform_fixture.fetch('terraform_outputs')
    Cache.instance.terraform_fixture.fetch(key.to_s)
  end

private

  def fake_env_vars
    ENV["AWS_ACCOUNT"] = "dev"
    ENV["DATADOG_API_KEY"] = "abcd1234"
    ENV["ENABLE_DATADOG"] = "true"
    ENV["LOGIT_SYSLOG_ADDRESS"] = ManifestHelpers::LOGIT_SYSLOG_ADDRESS
    ENV["LOGIT_SYSLOG_PORT"] = ManifestHelpers::LOGIT_SYSLOG_PORT
    ENV["LOGIT_CA_CERT"] = ManifestHelpers::LOGIT_CA_CERT
    ENV["SYSTEM_DNS_ZONE_NAME"] = ManifestHelpers::SYSTEM_DNS_ZONE_NAME
  end

  def render(arg_list)
    fake_env_vars
    output, error, status = Open3.capture3(arg_list.join(' '))
    expect(status).to be_success, "build_manifest.sh exited #{status.exitstatus}, stderr:\n#{error}"
    output
  end

  def load_runtime_config
    runtime_config = render([
      File.expand_path("../../../../shared/build_manifest.sh", __FILE__),
      File.expand_path("../../../runtime-config-base.yml", __FILE__),
      File.expand_path("../../../addons/datadog-agent.yml", __FILE__),
      File.expand_path("../../../addons-meta/datadog-agent.yml", __FILE__),
      File.expand_path("../../../addons/collectd.yml", __FILE__),
      File.expand_path("../../../addons-meta/collectd.yml", __FILE__),
      File.expand_path("../../../addons/syslog-forwarder.yml", __FILE__),
      File.expand_path("../../../addons-meta/syslog-forwarder.yml", __FILE__),
      File.expand_path("../../../../shared/spec/fixtures/vpc-terraform-outputs.yml", __FILE__),
      File.expand_path("../../../../shared/spec/fixtures/bosh-terraform-outputs.yml", __FILE__),
    ])

    # Deep freeze the object so that it's safe to use across multiple examples
    # without risk of state leaking.
    deep_freeze(YAML.safe_load(runtime_config))
  end

  def load_terraform_fixture
    data = merge_fixtures([
      File.expand_path("../../../../shared/spec/fixtures/vpc-terraform-outputs.yml", __FILE__),
      File.expand_path("../../../../shared/spec/fixtures/bosh-terraform-outputs.yml", __FILE__),
    ])
    deep_freeze(data)
  end

  def merge_fixtures(fixtures)
    final = {}
    fixtures.each do |fixture|
      new_fixture = YAML.load_file(File.expand_path(fixture, __FILE__))
      final.merge!(new_fixture) { |_key, a_val, b_val| a_val.merge b_val }
    end
    final
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

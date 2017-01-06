require 'open3'
require 'yaml'
require 'singleton'

module ManifestHelpers
  SYSTEM_DNS_ZONE_NAME = 'example.com'.freeze

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
      File.expand_path("../../../datadog-agent-addon.yml", __FILE__),
      File.expand_path("../../../../shared/deployments/datadog-agent.yml", __FILE__),
      File.expand_path("../../../../shared/deployments/collectd.yml", __FILE__),
      File.expand_path("../../../../shared/deployments/syslog.yml", __FILE__),
      File.expand_path("../../../../shared/spec/fixtures/terraform/*.yml", __FILE__),
    ])

    # Deep freeze the object so that it's safe to use across multiple examples
    # without risk of state leaking.
    deep_freeze(YAML.load(runtime_config))
  end

  def load_terraform_fixture
    data = YAML.load_file(File.expand_path("../../../../shared/spec/fixtures/terraform/terraform-outputs.yml", __FILE__))
    deep_freeze(data)
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

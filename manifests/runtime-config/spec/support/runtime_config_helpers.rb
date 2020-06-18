require "singleton"
require "open3"
require "yaml"
require "tempfile"
require "fileutils"

module RuntimeConfigHelpers
  SYSTEM_DNS_ZONE_NAME = "example.com".freeze

  class Cache
    include Singleton
    attr_accessor :runtime_config_with_defaults
  end

  def runtime_config_with_defaults
    Cache.instance.runtime_config_with_defaults ||= load_default_runtime_config
  end

  def self.deploy_env
    "spec"
  end

private

  def root
    Pathname(File.expand_path("../../../..", __dir__))
  end

  def fake_env_vars
    env = {}
    env["AWS_ACCOUNT"] = "dev"
    env["AWS_DEFAULT_REGION"] = "eu-west-1"
    env["DEPLOY_ENV"] = RuntimeConfigHelpers.deploy_env
    env
  end

  def load_default_runtime_config
    workdir = Pathname.new(Dir.mktmpdir("workdir"))

    env = fake_env_vars

    env["PAAS_BOOTSTRAP_DIR"] = root.to_s
    env["WORKDIR"] = workdir.to_s

    generate_unix_users_fixture("#{workdir}/unix-users-ops-file")

    output, error, status = Open3.capture3(
      env,
      root.join("manifests/runtime-config/scripts/generate-runtime-config.sh").to_s,
    )
    expect(status).to be_success, "generate-runtime-config.sh exited #{status.exitstatus}, stderr:\n#{error}"

    # Deep freeze the object so that it's safe to use across multiple examples
    # without risk of state leaking.
    deep_freeze(YAML.safe_load(output))
  ensure
    FileUtils.rm_rf(workdir)
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

RSpec.configuration.include RuntimeConfigHelpers

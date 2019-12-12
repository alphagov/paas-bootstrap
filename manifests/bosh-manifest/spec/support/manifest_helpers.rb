require 'singleton'
require 'open3'
require 'yaml'
require 'tempfile'
require 'fileutils'


module ManifestHelpers
  SYSTEM_DNS_ZONE_NAME = 'example.com'.freeze

  class Cache
    include Singleton
    attr_accessor :manifest_with_defaults
    attr_accessor :bosh_deployment_manifest
  end

  def manifest_with_defaults
    Cache.instance.manifest_with_defaults ||= load_default_manifest
  end

  def bosh_deployment_manifest
    Cache.instance.bosh_deployment_manifest ||= load_bosh_deployment_with_upstream_opsfiles
  end

  def self.deploy_env
    "spec"
  end

private

  def root
    Pathname(File.expand_path("../../../..", __dir__))
  end

  def vars_store_file
    @vars_store_file ||= Tempfile.open(['vars-store', '.yml'])
    Pathname(@vars_store_file)
  end

  def fake_env_vars
    env = {}
    env["BOSH_FQDN_EXTERNAL"] = "bosh-external.domain"
    env["BOSH_FQDN"] = "bosh.domain"
    env["AWS_ACCOUNT"] = "dev"
    env["AWS_DEFAULT_REGION"] = "eu-west-1"
    env["BOSH_INSTANCE_PROFILE"] = "bosh-director-build"
    env["DEPLOY_ENV"] = ManifestHelpers.deploy_env
    env["SYSTEM_DNS_ZONE_NAME"] = ManifestHelpers::SYSTEM_DNS_ZONE_NAME
    env
  end

  def load_default_manifest
    workdir = Pathname.new(Dir.mktmpdir("workdir"))

    env = fake_env_vars

    env['VARS_STORE'] = vars_store_file.to_s
    env['PAAS_BOOTSTRAP_DIR'] = root.to_s
    env['WORKDIR'] = workdir.to_s

    generate_bosh_secrets_fixture("#{workdir}/bosh-secrets")
    generate_google_oauth_secrets_fixture(
      "#{workdir}/bosh-uaa-google-oauth-secrets",
      'some-google-client-id',
      'some-google-client-secret',
    )
    generate_bosh_ca_certs(workdir)
    copy_terraform_fixtures("#{workdir}/terraform-outputs", %w(vpc bosh))

    output, error, status = Open3.capture3(
      env,
      root.join("manifests/bosh-manifest/scripts/generate-manifest.sh").to_s,
    )
    expect(status).to be_success, "generate-manifests.sh exited #{status.exitstatus}, stderr:\n#{error}"

    # Deep freeze the object so that it's safe to use across multiple examples
    # without risk of state leaking.
    deep_freeze(YAML.safe_load(output))
  ensure
    FileUtils.rm_rf(workdir)
  end

  def load_bosh_deployment_with_upstream_opsfiles
    upstream_ops_file = Dir.glob(root.join('manifests/bosh-manifest/operations.d/*-UPSTREAM.yml')).sort.map { |x| "--ops-file=#{x}" }
    base_manifest_file = root.join('manifests/bosh-manifest/upstream/bosh.yml')

    output, error, status = Open3.capture3(
      "bosh interpolate #{upstream_ops_file.join(' ')} #{base_manifest_file}"
    )
    expect(status).to be_success, "generate bosh-deployment manifest with upstream opsfile failed with #{status.exitstatus}, stderr:\n#{error}"

    # Deep freeze the object so that it's safe to use across multiple examples
    # without risk of state leaking.
    deep_freeze(YAML.safe_load(output))
  end

  def generate_bosh_ca_certs(dir)
    output, error, status = Open3.capture3(
      "bash", "-e", "-c",
      '
        certstrap init --years "10" --passphrase "" --common-name bosh-CA
        mkdir -p certs
        mv out/* certs
      ',
      chdir: dir.to_s,
    )
    unless status.success?
      raise "Error generating bosh-secrets, exit: #{status.exitstatus}, output:\n#{output}\n#{error}"
    end
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

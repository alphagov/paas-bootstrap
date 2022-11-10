module FixtureHelpers
  def terraform_fixture_value(key, fixture)
    YAML.safe_load_file(fixtures_dir.join("#{fixture}-terraform-outputs.yml"), aliases: true).fetch("terraform_outputs_#{key}")
  end

  def copy_terraform_fixtures(target_dir, fixtures)
    fixtures.each do |fixture|
      copy_fixture_file("#{fixture}-terraform-outputs.yml", target_dir)
    end
  end

  def copy_fixture_file(file, target_dir, target_file = file)
    FileUtils.mkdir(target_dir) unless Dir.exist?(target_dir)
    FileUtils.cp(fixtures_dir.join(file), "#{target_dir}/#{target_file}")
  end

  def generate_bosh_secrets_fixture(target_dir)
    FileUtils.mkdir(target_dir) unless Dir.exist?(target_dir)
    File.open("#{target_dir}/bosh-secrets.yml", "w") do |file|
      output, error, status = Open3.capture3(File.expand_path("../../../bosh-manifest/scripts/generate-bosh-secrets.rb", __dir__))
      unless status.success?
        raise "Error generating bosh-secrets, exit: #{status.exitstatus}, output:\n#{output}\n#{error}"
      end

      file.write(output)
    end
  end

  def generate_google_oauth_secrets_fixture(target_dir, google_oauth_client_id, google_oauth_client_secret)
    FileUtils.mkdir(target_dir) unless Dir.exist?(target_dir)
    File.open("#{target_dir}/bosh-uaa-google-oauth-secrets.yml", "w") do |file|
      file.write({
        "admin_google_oauth_client_id" => google_oauth_client_id,
        "admin_google_oauth_client_secret" => google_oauth_client_secret,
      }.to_yaml)
    end
  end

  def generate_cyber_secrets_fixture(target_dir, bosh_auditor_splunk_hec_token)
    FileUtils.mkdir(target_dir) unless Dir.exist?(target_dir)
    File.open("#{target_dir}/bosh-cyber-secrets.yml", "w") do |file|
      file.write({
        "bosh_auditor_splunk_hec_token" => bosh_auditor_splunk_hec_token,
      }.to_yaml)
    end
  end

  def generate_uaa_users_fixture(target_dir)
    FileUtils.mkdir(target_dir) unless Dir.exist?(target_dir)
    File.open("#{target_dir}/uaa-users-ops-file.yml", "w") do |file|
      file.write "[]"
    end
  end

  def generate_unix_users_fixture(target_dir)
    FileUtils.mkdir(target_dir) unless Dir.exist?(target_dir)
    File.open("#{target_dir}/unix-users-ops-file.yml", "w") do |file|
      file.write "[]"
    end
  end

private

  def fixtures_dir
    Pathname.new(File.expand_path("../fixtures", __dir__))
  end
end

RSpec.configuration.include FixtureHelpers

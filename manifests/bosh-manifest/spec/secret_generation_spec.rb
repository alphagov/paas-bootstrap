require "tempfile"

RSpec.describe "secret generation" do
  describe "generate-bosh-secrets" do
    specify "it should produce lint-free YAML" do
      dir = Dir.mktmpdir("paas-bootstrap-test")
      begin
        generate_bosh_secrets_fixture(dir)

        output, status = Open3.capture2e("yamllint", "-c", File.expand_path("../../../yamllint.yml", __dir__), "#{dir}/bosh-secrets.yml")

        expect(status).to be_success, "yamllint exited #{status.exitstatus}, output:\n#{output}"
        expect(output).to be_empty
      ensure
        FileUtils.rm_rf(dir)
      end
    end
  end
end

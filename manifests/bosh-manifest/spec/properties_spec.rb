RSpec.describe "manifest properties validations" do
  let(:manifest) { manifest_with_defaults }
  let(:bosh_instance_group) { manifest.fetch("instance_groups").select { |x| x["name"] == "bosh" }.first }
  let(:bosh_properties) { bosh_instance_group.fetch("properties") }

  it "configures hm bosh user with password" do
    users = bosh_properties["director"]["user_management"]["local"]["users"]
    hm = users.find { |u| u['name'] == 'hm' }
    expect(hm).to be
    expect(hm["password"]).to eq(bosh_secrets_value('bosh_hm_director_password'))
  end

  it "configures admin bosh user with password" do
    users = bosh_properties["director"]["user_management"]["local"]["users"]
    admin = users.find { |u| u['name'] == 'admin' }
    expect(admin).to be
    expect(admin["password"]).to eq(bosh_secrets_value('bosh_admin_password'))
  end

  it "creates a local user for health manager" do
    users = bosh_properties["director"]["user_management"]["local"]["users"]
    expected_user = { "name" => "hm", "password" => bosh_secrets_value('bosh_hm_director_password') }
    expect(users).to include(expected_user)
  end

  it "configures the hm bosh user as director account of the health manager" do
    expect(bosh_properties["hm"]["director_account"]["user"]).to eq("hm")
    expect(bosh_properties["hm"]["director_account"]["password"]).to eq(bosh_secrets_value('bosh_hm_director_password'))
  end

  it "disables the health manager resurrector" do
    expect(bosh_properties["hm"]["resurrector_enabled"]).to eq(false)
  end

  it "configures datadog tag bosh-job" do
    expect(bosh_properties["tags"]["bosh-job"]).to eq("bosh")
  end

  it "sets the bosh director name to the value of DEPLOY_ENV" do
    expect(bosh_properties["director"]["name"]).to eq(ManifestHelpers.deploy_env)
  end
end

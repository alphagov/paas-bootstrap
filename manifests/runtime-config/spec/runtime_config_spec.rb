
RSpec.describe "Runtime config" do
  let(:runtime_config) { default_runtime_config }

  it "has an addons block" do
    expect(runtime_config["addons"]).to be
  end
end

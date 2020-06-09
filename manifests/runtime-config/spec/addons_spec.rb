RSpec.describe "runtime config addons" do
  let(:runtime_config) { runtime_config_with_defaults }
  let(:addons) { runtime_config.fetch("addons") }

  it "it should have addons" do
    expect(addons).to be_a Array
    expect(addons).not_to eq([])
  end

  %w[node_exporter awslogs].each do |addon_name|
    it "should have the #{addon_name} addon" do
      addon = addons.find { |r| r["name"] == addon_name }

      expect(addon).not_to be_nil
    end
  end
end

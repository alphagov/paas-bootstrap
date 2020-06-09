RSpec.describe "generic runtime config validations" do
  let(:runtime_config) { runtime_config_with_defaults }

  it "should render the runtime config" do
    expect { runtime_config }.not_to raise_error
  end
end

require 'tempfile'
require 'yaml'

require_relative '../scripts/generate-uaa-users-ops-file'

def with_temp_users_file(contents)
  Tempfile.create('users.yml') do |f|
    f.write contents
    f.flush
    yield f
  end
end

RSpec.describe 'Generating UAA users ops file' do
  it 'Generates an empty ops file if no users are present' do
    with_temp_users_file 'users: []' do |f|
      result_str = generate_uaa_users_ops_file(f.path, 'some-aws-env')
      result_yaml = YAML.safe_load(result_str)
      expect(result_yaml).to eql([{
        'type' => 'replace',
        'path' => '/instance_groups/name=bosh/jobs/name=uaa/properties/uaa/scim/users',
        'value' => [],
      }])
    end
  end

  it 'Generates an ops file with bosh-admins for the current environment based on the config' do
    users = {
      'users' => [
        {
          'email' => 'some-admin-email@digital.cabinet-office.gov.uk',
          'roles' => { 'prod' => [{ 'role' => 'bosh-admin' }] },
        },
        {
          'email' => 'some-admin-for-a-different-env-email@digital.cabinet-office.gov.uk',
          'roles' => { 'dev' => [{ 'role' => 'bosh-admin' }] },
        },
        {
          'email' => 'some-unrelated-roles-email@digital.cabinet-office.gov.uk',
          'roles' => { 'prod' => [{ 'role' => 'some-unrelated-role' }] },
        },
        {
          'email' => 'some-no-roles-email@digital.cabinet-office.gov.uk',
          'roles' => { 'prod' => [] },
        },
        {
          'email' => 'some-empty-roles-email@digital.cabinet-office.gov.uk',
          'roles' => {},
        },
      ],
    }
    with_temp_users_file users.to_yaml do |f|
      result_str = generate_uaa_users_ops_file(f.path, 'prod')
      result_yaml = YAML.safe_load(result_str)
      expect(result_yaml).to eql([{
        'type' => 'replace',
        'path' => '/instance_groups/name=bosh/jobs/name=uaa/properties/uaa/scim/users',
        'value' => [{
          'email' => 'some-admin-email@digital.cabinet-office.gov.uk',
          'name' => 'some-admin-email@digital.cabinet-office.gov.uk',
          'origin' => 'admin-google',
          'groups' => ['bosh.admin'],
        }],
      }])
    end
  end
end

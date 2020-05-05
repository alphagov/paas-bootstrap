require 'tempfile'
require 'yaml'

require_relative '../scripts/generate-unix-users-ops-file'

def with_temp_users_file(contents)
  Tempfile.create('users.yml') do |f|
    f.write contents
    f.flush
    yield f
  end
end

RSpec.describe 'Generating unix users ops file' do
  release_op_to_add = {
    'type' => 'replace',
    'path' => '/releases/-',
    'value' => {
      'name' => 'os-conf',
      'version' => '21.0.0',
      'url' => 'https://bosh.io/d/github.com/cloudfoundry/os-conf-release?v=21.0.0',
      'sha1' => '7579a96515b265c6d828924bf4f5fae115798199',
    },
  }

  it 'Generates an empty ops file if no users are present' do
    with_temp_users_file 'users: []' do |f|
      result_str = generate_unix_users_ops_file(f.path, 'some-aws-env')
      result_yaml = YAML.safe_load(result_str)
      expect(result_yaml).to eql([release_op_to_add, {
        'type' => 'replace',
        'path' => '/instance_groups/name=bosh/jobs/-',
        'value' => {
          'name' => 'user_add',
          'release' => 'os-conf',
          'properties' => {
            'users' => []
          },
        },
      }])
    end
  end

  it 'Generates an ops file with bosh-admins for the current environment based on the config' do
    users = {
      'users' => [
        {
          'email' => 'some-admin-email@digital.cabinet-office.gov.uk',
          'roles' => { 'prod' => [
            { 'role' => 'bosh-admin' },
            { 'role' => 'ssh-access' },
          ] },
          'ssh' => {
            'username' => 'someadmin',
            'public_key' => 'ssh public key 1',
          },
        },
        {
          'email' => 'some-admin-for-a-different-env-email@digital.cabinet-office.gov.uk',
          'roles' => { 'dev' => [
            { 'role' => 'bosh-admin' },
            { 'role' => 'ssh-access' },
          ] },
          'ssh' => {
            'username' => 'someotheradmin',
            'public_key' => 'ssh public key 2',
          },
        },
        {
          'email' => 'some-unrelated-roles-email@digital.cabinet-office.gov.uk',
          'roles' => { 'prod' => [{ 'role' => 'some-unrelated-role' }] },
          'ssh' => {
            'username' => 'unrelated',
            'public_key' => 'ssh public key 3',
          },
        },
        {
          'email' => 'some-no-roles-email@digital.cabinet-office.gov.uk',
          'roles' => { 'prod' => [] },
          'ssh' => {
            'username' => 'norolesinprod',
            'public_key' => 'ssh public key 4',
          },
        },
        {
          'email' => 'some-empty-roles-email@digital.cabinet-office.gov.uk',
          'roles' => {},
          'ssh' => {
            'username' => 'norolesatall',
            'public_key' => 'ssh public key 5',
          },
        },
      ],
    }
    with_temp_users_file users.to_yaml do |f|
      result_str = generate_unix_users_ops_file(f.path, 'prod')
      result_yaml = YAML.safe_load(result_str)
      expect(result_yaml).to eql([release_op_to_add, {
        'type' => 'replace',
        'path' => '/instance_groups/name=bosh/jobs/-',
        'value' => {
          'name' => 'user_add',
          'release' => 'os-conf',
          'properties' => {
            'users' => [{
              'name' => 'someadmin',
              'public_key' => 'ssh public key 1',
            }]
          },
        },
      }])
    end
  end
end

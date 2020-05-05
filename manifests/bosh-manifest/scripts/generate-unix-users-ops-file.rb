#!/usr/bin/env ruby

require 'English'
require 'yaml'

def generate_unix_users_ops_file(config_file, aws_account)
  if File.file? config_file
    users_config = YAML.load_file config_file

    unix_users = users_config.fetch('users').select do |u|
      u.dig('roles', aws_account)&.any? { |r| r['role'] == 'ssh-access' }
    end

    ssh_users = unix_users.map do |user|
      {
        'name' => user.dig('ssh', 'username'),
        'public_key' => user.dig('ssh', 'public_key'),
      }
    end

    [{
      'type' => 'replace',
      'path' => '/releases/-',
      'value' => {
        'name' => 'os-conf',
        'version' => '21.0.0',
        'url' => 'https://bosh.io/d/github.com/cloudfoundry/os-conf-release?v=21.0.0',
        'sha1' => '7579a96515b265c6d828924bf4f5fae115798199',
      },
    }, {
      'type' => 'replace',
      'path' => '/instance_groups/name=bosh/jobs/-',
      'value' => {
        'name' => 'user_add',
        'release' => 'os-conf',
        'properties' => {
          'users' => ssh_users
        },
      },
    }].to_yaml
  end
end

if $PROGRAM_NAME == __FILE__
  config_file = ARGV[0]
  aws_account = ARGV[1]

  puts generate_unix_users_ops_file(config_file, aws_account)
end

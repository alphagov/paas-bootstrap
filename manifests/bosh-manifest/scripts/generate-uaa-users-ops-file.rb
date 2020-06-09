#!/usr/bin/env ruby

require "English"
require "yaml"

def generate_uaa_users_ops_file(config_file, aws_account)
  named_roles_to_groups = {
    "bosh-admin" => [
      "bosh.admin",
      "credhub.read", "credhub.write",
      "uaa.admin"
    ]
  }

  ops_file = [{
    "type" => "replace",
    "path" => "/instance_groups/name=bosh/jobs/name=uaa/properties/uaa/scim/users",
    "value" => []
  }]

  if File.file? config_file
    users_config = YAML.load_file config_file
    users_and_groups = users_config
      .fetch("users")
      .map do |user|
        groups = (user.dig("roles", aws_account) || []).flat_map { |entry| named_roles_to_groups.fetch(entry["role"], []) }
        [user, groups]
      end

    ops_file[0]["value"] = users_and_groups
      .reject { |_user, groups| groups.empty? }
      .map do |user, groups|
        email = user.fetch("email")
        {
          "email" => email,
          "name" => email,
          "origin" => "admin-google",
          "groups" => groups.uniq,
        }
      end

    ops_file.to_yaml
  end
end

if $PROGRAM_NAME == __FILE__
  config_file = ARGV[0]
  aws_account = ARGV[1]

  puts generate_uaa_users_ops_file(config_file, aws_account)
end

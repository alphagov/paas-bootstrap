#!/usr/bin/env ruby

require 'yaml'

def usage
  abort "Usage: #{__FILE__} <manifest_file>"
end

def upload_release(details)
  cmd = [
    "bosh", "upload", "release",
    "--name", details.fetch("name"),
    "--version", details.fetch("version"),
    "--sha1", details.fetch("sha1"),
    details.fetch("url"),
  ]
  puts "Executing: #{cmd.join(' ')}"
  unless Kernel.system(*cmd)
    abort "Error: command exited #{$?.exitstatus}."
  end
end

if ARGV.size != 1
  usage
end

manifest = YAML.load_file(ARGV[0])
manifest.fetch("releases").each do |release|
  upload_release(release)
end

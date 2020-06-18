#!/usr/bin/env ruby

require "English"
require "openssl"
require "yaml"

filename = ARGV.first
raise "#{$PROGRAM_NAME} requires a vars store filename argument" if filename.nil?

puts "Loading file #{filename}"
contents = YAML.load_file(filename)
puts "Loaded file #{filename}"

raise "Could not parse vars file #{filename}" unless contents.is_a?(Hash)

puts "Old variable names: #{contents.keys}"

mbus_bootstrap_ssl_cert = contents.dig("mbus_bootstrap_ssl", "certificate")
unless mbus_bootstrap_ssl_cert.nil?
  puts "Found mbus_bootstrap_ssl, checking it"
  # We need mbus_bootstrap_ssl to have:
  # Common name => bosh-external.((system_domain))
  begin
    puts "Parsing mbus_bootstrap_ssl"
    cert = OpenSSL::X509::Certificate.new(mbus_bootstrap_ssl_cert)
    san = cert.extensions.find { |ext| ext.oid == "subjectAltName" }.value
    puts "Parsed mbus_bootstrap_ssl"

    if san.match?(/bosh-external/)
      puts "Nothing to do for mbus_bootstrap_ssl"
    else
      puts "Deleting mbus_bootstrap_ssl"
      contents.delete("mbus_bootstrap_ssl")
    end
  rescue StandardError => e
    puts "Handled error => #{e}\n#{e.backtrace}."
    puts "Deleting mbus_bootstrap_ssl, due to unforeseen error, this is okay"
    contents.delete("mbus_bootstrap_ssl")
  end
end

uaa_service_provider_ssl_cert = contents.dig("uaa_service_provider_ssl", "certificate")
unless uaa_service_provider_ssl_cert.nil?
  puts "Found uaa_service_provider_ssl, checking it"
  # We need uaa_service_provider_ssl to have:
  # Common name => bosh-external.((system_domain))
  begin
    puts "Parsing uaa_service_provider_ssl"
    cert = OpenSSL::X509::Certificate.new(uaa_service_provider_ssl_cert)
    san = cert.extensions.find { |ext| ext.oid == "subjectAltName" }.value
    puts "Parsed uaa_service_provider_ssl"

    if san.match?(/bosh-external/)
      puts "Nothing to do for uaa_service_provider_ssl"
    else
      puts "Deleting uaa_service_provider_ssl"
      contents.delete("uaa_service_provider_ssl")
    end
  rescue StandardError => e
    puts "Handled error => #{e}\n#{e.backtrace}."
    puts "Deleting uaa_service_provider_ssl, due to unforeseen error, this is okay"
    contents.delete("uaa_service_provider_ssl")
  end
end

uaa_ssl_cert = contents.dig("uaa_ssl", "certificate")
unless uaa_ssl_cert.nil?
  puts "Found uaa_ssl, checking it"
  # We need uaa_ssl to have:
  # Common name => bosh-external.((system_domain))
  begin
    puts "Parsing uaa_ssl"
    cert = OpenSSL::X509::Certificate.new(uaa_ssl_cert)
    san = cert.extensions.find { |ext| ext.oid == "subjectAltName" }.value
    puts "Parsed uaa_ssl"

    if san.match?(/bosh-external/)
      puts "Nothing to do for uaa_ssl"
    else
      puts "Deleting uaa_ssl"
      contents.delete("uaa_ssl")
    end
  rescue StandardError => e
    puts "Handled error => #{e}\n#{e.backtrace}."
    puts "Deleting uaa_ssl, due to unforeseen error, this is okay"
    contents.delete("uaa_ssl")
  end
end

puts "New variable names: #{contents.keys}"

puts "Writing file #{filename}"
File.write(filename, contents.to_yaml)

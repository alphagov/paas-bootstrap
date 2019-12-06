// Used by scripts/bosh-cli.sh to proxy requests to things running on the bosh
// director using the SOCKS5 proxy set up by our SSH tunnel.

function FindProxyForURL(url, host) {

  if (shExpMatch(host, "bosh.*.dev.cloudpipeline.digital")          ||
      shExpMatch(host, "bosh.build.ci.cloudpipeline.digital")       ||
      shExpMatch(host, "bosh.london.staging.cloudpipeline.digital") ||
      shExpMatch(host, "bosh.cloud.service.gov.uk")                 ||
      shExpMatch(host, "bosh.london.cloud.service.gov.uk")) {
    return "SOCKS localhost:25555; SOCKS5 localhost:25555";
  }

  return "DIRECT";
}

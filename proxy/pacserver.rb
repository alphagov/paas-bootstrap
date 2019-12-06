require 'webrick'

server = WEBrick::HTTPServer.new Port: 9191

proxy = File.read(File.expand_path(File.join(__dir__, 'proxy.pac')))

server.mount_proc '/' do |_req, res|
  res.status = 200
  res['Content-Type'] = 'application/x-ns-proxy-autoconfig'
  res.body = proxy
end

trap 'INT' do server.shutdown end

server.start

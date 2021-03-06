require 'eventmachine'
require 'json'
require 'em-websocket'
require 'ostruct'

include ActionView::Helpers::NumberHelper
include ApplicationHelper
include Rails.application.routes.url_helpers

def compile_block_haml(block)
  ctx = OpenStruct.new(:blk => block)
  template = File.read(File.join(Rails.root, "app/views/blocks/_blk.html.haml"))
  res = Haml::Engine.new(template).render(ctx)
  "<tr>#{res.gsub!("\n", '')}</tr>"
end

File.open(File.join(Rails.root, "tmp/pids/websocket.pid"), "w") {|f| f.write Process.pid }

EM.run do
  bc_host, bc_port = BB_CONFIG["command"].split(":")

  CHANNEL = EM::Channel.new
  CLIENTS = {}

  log = Bitcoin::Logger.create(:websocket, :debug)

  Bitcoin::Node::CommandClient.connect(bc_host, bc_port) do
    on_connected do
      log.info { "Connected to bitcoin node" }
      request("monitor", channel: "block")
    end
    on_block do |blk, height|
      block = STORE.block(blk['hash'])
      log.info { "new block: #{block.height} #{block.hash}" }
      CHANNEL.push ["new_block", {height: block.height, json: block.to_hash,
                      partial: compile_block_haml(STORE.db[:blk][id: block.id])}]
      log.debug { "pushed block #{block.height}" }
      # TODO: fix caching properly
      cache_dir = File.join(Rails.root, "tmp/cache/")
      FileUtils.rm_rf cache_dir
      FileUtils.mkdir_p cache_dir
    end
  end

  EventMachine::WebSocket.start(WS_CONFIG.deep_symbolize_keys) do |ws|
    sid = nil

    ws.onopen do
      port, host = *Socket.unpack_sockaddr_in(ws.get_peername)
      log.info { "websocket client connected: #{host}:#{port}" }
      sid = CHANNEL.subscribe {|msg| ws.send msg.to_json }
      CLIENTS[sid] = [host, port]
      CHANNEL.push ["client_count", CLIENTS.size]
    end
    ws.onclose do
      host, port = *CLIENTS[sid]
      log.info { "websocket client disconnected: #{host}:#{port}" }
      CHANNEL.unsubscribe(sid)
      CLIENTS.delete(sid)
      CHANNEL.push ["client_count", CLIENTS.size]
    end
  end

    log.info { "websocket listening on #{WS_CONFIG['host']}:#{WS_CONFIG['port']}" }
end

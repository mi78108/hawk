require 'socket'
require 'logger'
require 'json'
require 'pathname'
# -*- coding: UTF-8 -*-
# encoding:utf-8

Log = Logger.new(STDOUT)
Log.level = Logger::INFO

WEBROOT = Pathname(__FILE__).realpath.join('../../www/').freeze

class Http
  def initialize(port = 2000, config = {})
    @Requests = {}
    @Handle = {}
    @Config = {
        'API_DOWNCASE' => false
    }.merge config
    @Server = TCPServer.open(port)
    Log.info "Web Server Set on Port: #{port}"
  end

  attr_accessor :Requests

  def start
    Log.info "Web Server Start at: #{Time.now}"
    loop {
      Thread.start(@Server.accept) do |client|
        r = Request.new(client)
        k = r.get_api
        k.downcase! if @Config['API_DOWNCASE']

        handle = nil
        # Api Is String
        if (hs = @Handle[k])
          if (h = hs[r.get_pro])
            handle = h
          end
        else
          # Api Is Regexp
          @Handle.each do |hs, v|
            next unless hs.class == Regexp
            next unless k =~ hs
            if (h = v[r.get_pro])
              handle = h
              r.get_params['api_param'] = k.scan hs
              break
            end
          end
        end
        #
        if handle
          handle.do_work r, Response.new(nil, Http_code::HTTP_OK, r.get_ver)
        else
          # Not Api found
          r.send Response.new(Http_code::MIME_HTML,
                              Http_code::HTTP_NOT_FOUND,
                              r.get_ver).to_be_send
          Log.info("Resp 404 On #{r.get_pro} Map #{r.get_api}")
        end
        Log.info "Handle #{r.get_api} End\n"
        client.close
      end
    }
  end

  def map(api, &block)
    api.downcase! if @Config['API_DOWNCASE'] && api.class == String
    h = Handle.new(api, self)
    init_handle api
    h.on 'GET|POST', &block
    # @Handle[api] = Hash['GET' => h, 'POST' => h]
    h
  end

  def add_handle(api, pro, handle)
    @Handle[api][pro] = handle
  end

  def get_handle(api)
    @Handle[api]
  end

  def init_handle(api)
    @Handle[api] = Hash.new
  end
end

class Handle
  def initialize(api, http)
    @hp = http
    @api = api
  end

  def on(protocols = 'GET|POST', &block)
    @hp.get_handle(@api).clear
    protocols.upcase!
    protocols.split(/[,| ;]/).each do |p|
      @hp.add_handle(@api, p, self)
    end
    set_block &block if block
    @hp
  end

  def server_start
    @hp.start
  end

  def set_block(&block)
    @block = block
  end

# @param [Request] req

# @param [Response] resp
  def do_work(req, resp)
    if @block
      @block.call req, resp
      send_response req, resp
    else
      Log.info 'Handle Block Not Register'
    end
  end

  def send_response(req, resp)
    body_size = -1
    body_size = 0 if resp.body.nil?
    body_size = resp.body.size if body_size < 0
    Log.info("Resp #{resp.code} On #{req.get_pro} Map #{req.get_api} Lenght: #{body_size} Time: #{Time.now - req.start_time}s")
    req.send resp.to_be_send
  end
end


class Request
  attr_reader :start_time

  # @param [Request] c
  def initialize(c)
    @start_time = Time.now
    @socket = c
    @pro, @url, @ver = c.gets.split(' ')
    # p "#{@pro}  #{@url}  #{@ver}"
    @head = {}
    @param = {}
    c.each do |h|
      break if h == "\r\n" || h == "\n"
      _t = h.split(':')
      @head[_t[0].strip] = _t[1..].join(':').strip
    end

    if @pro == 'GET'
      @url.scan(%r{(\w+)=([\w/]*)}) do |param|
        @param[param[0]] = param[1]
      end
    end

    #@head.each {|h| p h }

    Log.info "Req Map #{@url} On #{@pro} From #{@socket.peeraddr}"
    # ws if
    if get_head('Upgrade') == 'websocket'
      require 'digest/sha1'
      require 'base64'
      dk = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'
      key = get_head('Sec-WebSocket-Key') + dk
      key = Digest::SHA1.digest(key)
      key = Base64.encode64(key).strip
      resp = Response.new(nil, Http_code::HTTP_SWITCH)
      resp.add_head({'Upgrade' => 'websocket', 'Connection' => 'Upgrade', 'Sec-WebSocket-Accept' => key})
      send resp.to_be_send
      Log.info "WS Connect #{key} Connected"
      # Switch
      @pro = 'WS'
      # del
    end
  end

  def stream(pro, &block)
    pro.call @socket, &block
  end

  def get_param(k)
    @param[k]
  end

  def get_params
    @param
  end

  def get_api
    @url.split('?')[0]
  end

  def get_pro
    @pro
  end

  def get_heads
    @head
  end

  def get_head(k)
    @head[k]
  end

  def get_ver
    @ver
  end

  def get_addr
    @socket.peeraddr
  end

  def get_addr_nginx
    "#{get_head('X-Real-IP')}:#{get_head('X-Real-PORT')}"
  end

  def send(msg)
    # p msg
    @socket.puts msg
  end
end


class Response
  @@ext_js = Array.new
  attr_reader :body

  def initialize(mime = Http_code::MIME_HTML, code = Http_code::HTTP_OK, version = 'HTTP/1.1')
    @stat_code = code
    @http_version = version
    @mime = mime
    @body
    @head = {
        :Server => 'mi-hawk  www_model',
        'Content-type' => @mime,
        :Data => Time.now
    }
  end

  def self.set_ext_js(js)
    @@ext_js.push js
  end

  def set_code(code)
    @stat_code = code
  end

  def code
    @stat_code
  end


  def add_head(head)
    @head.merge!(head)
  end

  def set_body_type(mime)
    @mime = mime
    add_head({'Content-type' => mime})
  end

  def set_body(body)
    if body
      add_head({
                   'Content-Length' => body.bytesize
               })
      @body = body
    end
  end

  # @return [String]
  def to_be_send
    resp = "#{@http_version} #{@stat_code} \r\n"
    # Path ext
    unless @body.nil?
      if @mime == Http_code::MIME_HTML
        ext_js = @@ext_js.flatten.join("\n")
        set_body @body.gsub(/<head>/, "<head>\n" + ext_js)
      end
    end
    @head.each do |k, v|
      next if v.nil?
      resp += "#{k}: #{v}\r\n"
    end
    "#{resp}\r\n#{@body}"
  end

  ##
  def render(name, exi = '.html')
    # p name
    set_body_type Http_code::MIME_HTML
    send_file Pathname.new(WEBROOT).join name + exi
  end

  def send_file(path, mime = nil)
    Log.info "Send File Path: #{path}"
    unless path.nil?
      File.foreach(path) do |line|
        @body = "#{@body}#{line}"
      end
      set_body @body
      Http_code.constants.each do |k|
        if k.to_s.start_with?('MIME') && k.to_s.end_with?(Pathname.new(path).basename.extname.gsub(/\./, '').upcase)
          set_body_type Http_code.const_get k
          break
        end
      end
    end
  end
end


module Http_code
  HTTP_OK = 200
  HTTP_BAD = 400
  HTTP_NOT_FOUND = 404
  HTTP_SWITCH = 101
  CRLF = "\r\n".freeze
  MIME_TEXT = 'text/plain'.freeze
  MIME_HTML = 'text/html'.freeze
  MIME_PNG = 'image/png'.freeze
  MIME_JSON = 'application/json'.freeze
  MIME_JS = 'application/javascript; charset=utf-8'.freeze
  MIME_CSS = 'text/css'.freeze
end

module Http_pro
  WS = {recv: proc do |c, &block|
    # p c.read 10
    # while (h = c.readbyte)
    # #Firt byte
    # 0     fin 1=over 0=goon
    # 1..3  ext not use
    # 4..7  opcode 0=date 1=text 2=bin 3..7=ext 8=close 9=ping A=pong B..F not use
    # #Scend byte
    # 0     mask=flags c->s must_be
    # 1..7  <126  7bit =126 + 16bit =127  +64bit data_lenght
    # 4 byte mark and data
    #
    # end
    loop do
      begin
        h1 = c.readbyte
        # ctrl close
        break if h1 == 0b10001000
        # ctrl ping
        if h1 == 0b10001001
          #
        end
        h2 = c.readbyte
        h2 = h2 ^ 128
        data = []
        if h2 < 126
          (h2 + 4).times do
            data.push c.readbyte
          end
        end
        if h2 == 126
          (2.times.reduce(4) do |sum, i|
            sum += c.getbyte << 8 * (1 - i)
          end).times do
            data.push c.readbyte
          end
        end
        if h2 == 127
          (8.times.reduce(4) do |sum, i|
            sum += c.getbyte << 8 * (7 - i)
          end).times do
            data.push c.readbyte
          end
        end
        mask = data[0..3]
        load = data[4..]
        load.each_with_index do |v, i|
          load[i] = v ^ mask[i % 4]
        end
        load = load.pack('C*').force_encoding('utf-8') if h1 == 129
        r = block.call load
          ### Recv
          # unless r.nil?
          #   Http_pro::WS[:send].call c, r
          # end
      rescue
        break
      end
    end
  end, send: proc do |c, &block|
    msg = block.call
    msg = msg.encode('utf-8').bytes
    m_l = msg.size
    # h1
    resp = [0x81]
    # h2
    (resp.push m_l) if m_l < 126
    if (m_l > 126 - 1) && (m_l < 1 << 16)
      (resp.push 126; 2.times { |i| resp.push(m_l >> 8 * (1 - i)) })
    end
    if (m_l > 1 << 16 - 1) && (m_l < 1 << 64)
      (resp.push(127); 8.times { |i| resp.push(m_l >> 8 * (7 - i)) })
    end
    # h3
    resp += msg
    c.write resp.pack('C*')
  end
  }.freeze
end


ext_js = {
    'jquery' => ['<script src="https://apps.bdimg.com/libs/jquery/2.1.4/jquery.min.js"></script>'],
    'layui' => ['<script src="https://www.layuicdn.com/layui/layui.js"></script>',
                '<link rel="stylesheet" type="text/css" href="https://www.layuicdn.com/layui/css/layui.css" />'],
    'layer' => ['<script src="https://www.layuicdn.com/layer/layer.js"></script>'],
    'vue' => ['<script src="https://cdn.staticfile.org/vue/2.2.2/vue.min.js"></script>']

}

Response.set_ext_js ext_js['layer']
Response.set_ext_js ext_js['jquery']
#Response.set_ext_js ext_js['layui']
#Response.set_ext_js ext_js['vue']

Hp = Http.new(2000)

Hp.map('/').on('GET') do |req, resp|
  resp.render 'html/index'
 #resp.set_code(302)
 #resp.add_head({'Location'=>"https://www.mihawk.xyz/room/1"})
end

Hp.map('/paste').on('GET') do |req, resp|
  resp.render 'html/paste'
end

Hp.map('/mark').on('GET') do |req, resp|
  resp.render 'html/markdown'
end

Hp.map('/paste/ws').on('GET|WS') do |req, resp|
  req.stream(Http_pro::WS[:recv]) do |r|
    req.stream(Http_pro::WS[:send]) do
      p r
      r
    end
  end
end


Hp.map(%r{room/(\d+)}i).on('GET|WS') do |req, resp|
  room_no = req.get_param('api_param')[0][0]
  resp.render 'html/room' if req.get_pro == 'GET'
  ##
  send_broadcast = Proc.new do |m, rn = room_no, with_self = false|
    Hp.Requests[rn].each do |r|
      next if r.equal? req unless with_self
      r.stream(Http_pro::WS[:send]) do
        m
      end
    end
  end
  ##
  if req.get_pro == 'WS'
    if Hp.Requests[room_no].nil?
      Hp.Requests[room_no] = [req]
    else
      #New Client Join Room
      Hp.Requests[room_no].push req
    end
    #New Init
    Log.info "Room #{room_no} Has #{Hp.Requests[room_no].size} Client"
    req.stream(Http_pro::WS[:send]) do
      "ROOM_NO:#{room_no}"
    end
    room_info = {
        :clients => Hp.Requests[room_no].size,
        :index => Hp.Requests[room_no].size - 1,
        :room_no => room_no,
        :ev_client_addr => req.get_addr_nginx,
        :ev_type => 'online'
    }
    send_broadcast.call "#{room_info.to_json}", room_no, true
    ##
    req.stream(Http_pro::WS[:recv]) do |m|
      # pong dor ping
      if m.to_s.start_with?('CTRL_PING_')
        req.stream(Http_pro::WS[:send]) do
          "CTRL_PONG_#{m.to_s.split('_')[2].to_i + 1}"
        end
        next
      end
      # brodcast
      send_broadcast.call m, room_no
    end
    Log.info "WS Room No #{room_no} over"
    Hp.Requests[room_no].delete req
    room_info = {
        :clients => Hp.Requests[room_no].size,
        :index => Hp.Requests[room_no].size - 1,
        :room_no => room_no,
        :ev_client_addr => req.get_addr_nginx,
        :ev_type => 'offline'
    }
    send_broadcast.call "#{room_info.to_json}", room_no
    Log.info "Room #{room_no} Has #{Hp.Requests[room_no].size} Client"
  end
end


Hp.map(%r{pub/(.*(js|css|png)$)}i) do |req, resp|
  req.get_param('api_param').map { |f| f[0] }.each do |f|
    path = Pathname.new(WEBROOT).join f
    if File.exist? path
      resp.send_file(path)
    else
      Log.info "Not Exits #{path}"
      resp.set_code Http_code::HTTP_NOT_FOUND
    end
  end
end

Hp.map('/say') do |req, resp|
  resp.set_body(req.get_heads.to_json)
end.server_start

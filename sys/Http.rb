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
        :API_DOWNCASE => false
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
          if (h = hs[r.pro])
            handle = h
          end
        else
          # Api Is Regexp
          @Handle.each do |hs, v|
            next unless hs.class == Regexp
            next unless k =~ hs
            if (h = v[r.pro])
              handle = h
              r.params['api_param'] = k.scan hs
              break
            end
          end
        end
        #
        if handle
          handle.do_work r, Response.new(nil, Http_code::HTTP_OK, r.ver)
        else
          # Not Api found
          r.send Response.new(Http_code::MIME_HTML,
                              Http_code::HTTP_NOT_FOUND,
                              r.ver).to_be_send
          Log.info("Resp 404 On #{r.pro} Map #{r.get_api}")
        end
        Log.info "Handle #{r.get_api} End\n"
        client.close
      end
    }
  end

  def map(api, &block)
    api.downcase! if @Config[:API_DOWNCASE] && api.class == String
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
    @Handle[api] = {}
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
    Log.info("Resp #{resp.code} On #{req.pro} Map #{req.get_api} Lenght: #{body_size} Time: #{Time.now - req.start_time}s")
    req.send resp.to_be_send
  end
end


class Request
  attr_reader :start_time
  attr_accessor :heads
  attr_accessor :params
  attr_reader :pro
  attr_reader :url
  attr_reader :ver

  # @param [Request] c
  def initialize(c)
    @start_time = Time.now
    @socket = c
    @pro, @url, @ver = c.gets.split(' ')
    # p "#{@pro}  #{@url}  #{@ver}"
    @heads = {}
    @params = {}
    @body
    c.each do |h|
      break if h == "\r\n" || h == "\n"
      _t = h.split(':')
      @heads[_t[0].strip] = _t[1..].join(':').strip
    end

    if @pro == 'GET'
      @url.scan(%r{(\w+)=([\w/]*)}) do |param|
        @params[param[0]] = param[1]
      end
    end

    #@head.each {|h| p h }

    Log.info "Req Map #{@url} On #{@pro} From #{@socket.peeraddr}"
    # ws if
    if heads['Upgrade'] == 'websocket'
      require 'digest/sha1'
      require 'base64'
      dk = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'
      key = heads['Sec-WebSocket-Key'] + dk
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

  def get_api
    @url.split('?')[0]
  end

  def get_body
	  if l = @heads['Content-Length'] and (@body.nil? or @body.empty?)
		  if l.to_i > 0
			  @body = Array.new(l.to_i).map { @socket.readbyte }
		  end
	  end
	  return	@body
  end

  def get_addr_nginx
    "#{heads['X-Real-IP']}:#{heads['X-Real-PORT']}"
  end

  def send(msg)
    # p msg
    begin
      @socket.puts msg unless @socket.closed?
    rescue Exception => e
      Log.error e.message
      Log.error e.backtrace.inspect
      @socket.close
      #ensure
    end
  end
end


class Response
  @@ext_js = []
  attr_reader :body

  def initialize(mime = Http_code::MIME_HTML, code = Http_code::HTTP_OK, version = 'HTTP/1.1')
    @stat_code = code
    @http_version = version
    @mime = mime
    @body
    @heads = {
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
    @heads.merge!(head)
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
    @heads.each do |k, v|
      next if v.nil?
      resp += "#{k}: #{v}\r\n"
    end
    "#{resp}\r\n#{@body}"
  end

  ##
  def render(name,arg = {} , exi = '.html')
    # p name
    set_body_type Http_code::MIME_HTML
    cb = Proc.new do |by|
      by.scan(%r|\#{(.*?)}|).each do |v|
        v=v.pop
        by.sub!('#{'+v+'}',arg[v].to_s)
      end
      by
    end
    send_file Pathname.new(WEBROOT).join(name + exi), cb
  end

  def send_file_download(path)
    Log.info "down File Path: #{path}"
    unless path.nil?
      File.open(path,"rb") do |fl|
        @body = "#{@body}#{fl.read}"
      end
      set_body @body
      add_head({
                   'Content-Type'=> 'application/octet-stream',
                   'Content-Disposition'=> "attachment; filename=#{path.split('/').pop}"
               })
    end
  end

  def send_file(path,cb = nil, mime = nil)
    Log.info "Send File Path: #{path}"
    unless path.nil?
      File.foreach(path) do |line|
        @body = "#{@body}#{line}"
      end
      if not cb.nil?
        @body = cb.call @body
        Log.info "Render By CB"
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
    msg = msg.to_s.encode('utf-8').bytes
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
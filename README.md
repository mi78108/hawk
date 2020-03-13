# ruby_web
Ruby 实现的简单 web，支持http/1.1 websocket ,支持自定义协议扩展. 使用Socket 库开发，依赖极少
```
require 'socket'
require 'logger'
require 'json'
require 'pathname'
```
* 自定义 get mapping
```
Hp.map('/').on('GET') do |req, resp|
  resp.render 'html/index'
end
```
* Get 和 Post 同时绑定(默认)
```
Hp.map('/paste').on('GET|POST') do |req, resp|
  resp.render 'html/paste'
end
```
* 路由 可以指定正则，并从同取得匹配值
```
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
```
* 绑定某自定义协议 例如Websocket
```
Hp.map('/paste/ws').on('GET|WS') do |req, resp|
  # 接受
  req.stream(Http_pro::WS[:recv]) do |r|
    # 发送
    req.stream(Http_pro::WS[:send]) do
      # 实现简单的WebSocket  echo 服务
      p r
      r
    end
  end
end
```
## 自定以协议扩展
Websocket 例子
```
module Http_pro
  WS = {recv: proc do |c, &block|
    # #First byte
    # 0     fin 1=over 0=go
    # 1..3  ext not use
    # 4..7  opcode 0=date 1=text 2=bin 3..7=ext 8=close 9=ping A=pong B..F not use
    # #Scend byte
    # 0     mask=flags c->s must_be
    # 1..7  <126  7bit =126 + 16bit =127  +64bit data_lenght
    # 4 byte mark and data
    #
    # end
    # 接收方法
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
      rescue
        break
      end
    end
  end
  # 发送方法
  , send: proc do |c, &block|
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
```
* 扩展直接在module 里追加即可

## 快速开始
```
Hp = Http.new(2000)

Hp.map('/').on('GET') do |req, resp|
  resp.render 'html/index'
end

Hp.server_start
```
OR
```
Hp = Http.new(2000).map('/') { |req, resp|  resp.render 'html/index' }.server_start
```
OR (map '/' on get and post defaults; and map /say on post only)
```
Hp = Http.new(2000)
  .map('/') { |req, resp|  resp.render 'html/index' }
  .map('/say').on('POST') { |req, resp| resp.set_body(req.get_heads.to_json) }
  .server_start
```

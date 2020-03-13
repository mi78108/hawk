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

# ruby_web
Ruby 实现的简单 web，支持http/1.1 websocket ,支持自定义协议扩展.
* 自定义 Mapping
```
Hp.map('/').on('GET') do |req, resp|
  resp.render 'html/index'
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
```


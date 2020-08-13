# -*- coding: UTF-8 -*-

require '../sys/Http'

ext_js = {
    'jquery' => ['<script src="https://apps.bdimg.com/libs/jquery/2.1.4/jquery.min.js"></script>'],
    'layui' => ['<script src="https://www.layuicdn.com/layui/layui.js"></script>',
                '<link rel="stylesheet" type="text/css" href="https://www.layuicdn.com/layui/css/layui.css" />'],
    'layer' => ['<script src="https://www.layuicdn.com/layer/layer.js"></script>'],
    'vue' => ['<script src="https://cdn.staticfile.org/vue/2.2.2/vue.min.js"></script>']

}

Response.set_ext_js ext_js['jquery']
Response.set_ext_js ext_js['layer']
#Response.set_ext_js ext_js['layui']
#Response.set_ext_js ext_js['vue']

Hp = Http.new(2000)

Hp.map('/').on('GET') do |req, resp|
  # resp.render 'html/index'
  resp.set_code(302)
  puts req.heads
  resp.add_head({'Location' => "http://#{req.heads['Host']}/room/1"})
end

Pastes = {}
Hp.map(%r{/paste(/?.+)*}).on('GET|WS') do |req, resp|
    if req.pro == 'GET'
      if req.params['api_param'][0][0]
        resp.render('html/paste',{"btn"=>"none"})
      else
        resp.render('html/paste')
      end
    end

  if req.pro == 'WS'
    if req.params['api_param'][0][0]
      key = req.params['api_param'][0][0][1..]
      p key
      req.stream(Http_pro::WS[:send]) do
        Pastes[key]
      end
      req.stream(Http_pro::WS[:recv]) do |v|
        p v
      end
    else
      req.stream(Http_pro::WS[:send]) do
        key = "#{Pastes.size}-#{"aa".chars.map {|_| ('a'..'z').to_a[rand(26)]}.join}"
        Pastes[key] = nil
        "CTRL_KEY_#{key}"
      end

      req.stream(Http_pro::WS[:recv]) do |r|
        r = r.split('_')
        key = r[3]
        if Pastes.has_key? key
          if r[2] == 'SET'
            Pastes[key] = r[4..].join
            Log.info "#{key} Text Set"
          end

          if r[2] == 'GET'
            m = Pastes[key]
            Log.info "#{key} Text Get"
            req.stream(Http_pro::WS[:send]) do
              m
            end
          end
        else
          Log.error "#{key} is Not Defined"
          req.stream(Http_pro::WS[:send]) do
            "CTRL_ERROR_Not Found"
          end
        end
      end

    end
  end
end

Hp.map(%r{room/(\d+)}i).on('GET|WS') do |req, resp|
  room_no = req.params['api_param'][0][0]
  resp.render 'html/room' if req.pro == 'GET'
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
  if req.pro == 'WS'
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
  req.params['api_param'].map { |f| f[0] }.each do |f|
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
  resp.set_body(req.heads.to_json)
end.server_start

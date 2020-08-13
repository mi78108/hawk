let _storeHash = {};

function log(msg) {
    console.log(msg)
}

function _get_added(k, cb) {
    if (_storeHash['_get_addeds']) {
        if (_storeHash['_get_addeds'][k]) {
            _storeHash['_get_addeds'][k].v = _storeHash['_get_addeds'][k].f(
                _storeHash['_get_addeds'][k].v
            );
            cb && cb(_storeHash['_get_addeds'][k])
        } else {
            //init
            _storeHash['_get_addeds'][k] = {
                v: cb && cb(null) || 0,
                f: cb || function (v) {
                    return v + 1
                }
            };
        }
        return _storeHash['_get_addeds'][k].v;
    } else {
        _storeHash['_get_addeds'] = {};
        return _get_added(k, cb);
    }

}

function set(id, cb) {
    let tdm = document.createElement("div");
    tdm.id = id;
    cb && cb(tdm)
}

function get_local_video(id) {
    let video = document.createElement("video");
    video.id = id;
    video.width = 320;
    video.height = 240;
    //add Event
    video.float = 'right';
    video.style.position = 'absolute';
    video.style.right = '10px';
    video.style.top = '10px';
    video.style.zIndex = '999';
    video.onmousedown = function (ev_d) {
        video.onmousemove = function (ev_m) {
            video.style.left = (ev_m.clientX - ev_d.layerX) + 'px';
            video.style.top = (ev_m.clientY - ev_d.layerY) + 'px';
        };
        video.onmouseup = function () {
            video.onmousemove = null;
            video.onmouseup = null;
        }
    };
    window.navigator.getUserMedia = MediaDevices.getUserMedia || navigator.getUserMedia || navigator.webKitGetUserMedia || navigator.mozGetUserMedia || navigator.msGetUserMedia;
    if (window.navigator.getUserMedia) {
        window.navigator.getUserMedia({
            //video: {facingMode: {exact: "environment"}}
            video: {'facingMode': "user"}
        }, onSuccess, function (e) {
            alert("Try To Share Screen");
            window.navigator.getUserMedia({
                //video: {facingMode: {exact: "environment"}}
                video: {'mediaSource': "screen"}
            }, onSuccess, function (ee) {
                alert(ee)
            });
        });
    } else {
        alert('your browser not support getUserMedia;');
    }

    function onSuccess(stream) {
        if (navigator.mozGetUserMedia) {
            video.srcObject = stream;
        } else {
            let vendorURL = window.URL || window.webkitURL;
            video.src = vendorURL.createObjectURL(stream);
        }
        video.onloadedmetadata = function (e) {
            video.play();
        };
        peerConnection.addStream(stream);
    }

    return video;
}


function webRtc() {
    window.RTCPeerConnection = window.mozRTCPeerConnection || window.webkitRTCPeerConnection;
    let peerConnection = new RTCPeerConnection(null);

    window.navigator.getUserMedia = MediaDevices.getUserMedia || navigator.getUserMedia || navigator.webKitGetUserMedia || navigator.mozGetUserMedia || navigator.msGetUserMedia;
    if (window.navigator.getUserMedia) {
        window.navigator.getUserMedia({
            //video: {facingMode: {exact: "environment"}}
            video: {'facingMode': "user"}
        }, onSuccess, function (e) {
            alert("Try To Share Screen");
            window.navigator.getUserMedia({
                //video: {facingMode: {exact: "environment"}}
                video: {'mediaSource': "screen"}
            }, onSuccess, function (ee) {
                alert(ee)
            });
        });
    } else {
        alert('your browser not support getUserMedia;');
    }

    function onSuccess(stream) {
        peerConnection.addStream(stream);
        //
        peerConnection.createOffer(function (desc) {
            console.log("创建offer成功");
            // 将创建好的offer设置为本地offer
            peerConnection.setLocalDescription(desc);
            // 通过socket发送offer
        }, function (error) {
            // 创建offer失败
            console.log("创建offer失败");
        })
    }
}

function copyToclip(txt) {
             if (document.execCommand("copy")) {
                   const input = document.createElement("input"); // 创建一个新input标签
                   input.setAttribute("readonly", "readonly"); // 设置input标签只读属性
                   input.setAttribute("value", txt); // 设置input value值为需要复制的内容
                   document.body.appendChild(input); // 添加input标签到页面
                   input.select(); // 选中input内容
                   input.setSelectionRange(0, 9999); // 设置选中input内容范围
                   document.execCommand("copy"); // 复制
                   document.body.removeChild(input);  // 删除新创建的input标签
                 }
           }
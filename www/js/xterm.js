//检查jquery
window.jQuery || document.write("<script src='https://apps.bdimg.com/libs/jquery/2.1.4/jquery.min.js'></script>")

//
class Xterm {
    //事件驱动
    constructor(tdm, cb) {
        this.last_cb=function (){
            let now = new Date();
            return now.getHours()+":"+now.getMinutes()+":"+now.getSeconds();
        };
        this.x = 0;
        this.y = 0;
        this.cb = cb;
        this.tdm = tdm.get(0);
        this.prompt = '> ';

        this.row_h = 40;

        this.tb = document.createElement("table");
        this.ip = document.createElement("div");
        this.ip.id = "uip";
        this.ip.style.backgroundColor = this.tdm.style.backgroundColor;
        this.ip.contentEditable = "true";
        this.ip.style.width = "100%";
        this.ip.style.outline = "none";
        this.ip.style.color = 'white';
        this.ip.style.minHeight = this.row_h / 2 + 'px';

        this.tb.style.width = "100%";
        this.tb.style.color = "white";
        this.tb.style.tableLayout = "fixed";
        // this.tb.style.height = "100%";
        this.tdm.append(this.tb);
        let self = this;
        this.firstLine = this.insertLine(null, 0, function (v) {
            v.cells.item(0).innerHTML = self.prompt;
            v.cells.item(1).appendChild(self.ip)
        });
        //Ev
        this.key_ev = this.hotKey();
        //Auto focus or click
        let tip = this.ip;
        this.tdm.onmouseenter = function () {
            tip.focus()
        };
        this.tdm.onclick = function () {
            tip.focus()
        };
        //Enter
        this.ip.onkeydown = function (ev) {
            if (self.key_ev[ev.keyCode]) {
                self.key_ev[ev.keyCode](ev)
            }
        }
    }


    hotKey(k, cb) {
        if (k === undefined && cb === undefined) {
            if (this.key_ev === undefined) {
                let self = this;
                //defult
                return {
                    13: function (ev) {
                        //ctrl+enter
                        if (ev.ctrlKey) {
                            self.ip.innerHTML += '<br>';
                            let sel = window.getSelection();
                            sel.setPosition(self.ip, sel.rangeCount + 1)
                        } else {
                            ev.preventDefault();
                            let v = self.ip.innerHTML;
                            self.insertLine([self.prompt + v]);
                            while (self.ip.hasChildNodes()) {
                                self.ip.removeChild(self.ip.lastChild);
                            }
                            self.cb && self.cb(v);
                        }
                    },

                };
            }
            return this.key_ev;
        } else {
            this.key_ev[k] = cb;
        }
    }

    insertLine(hs, n = 1, cb) {
        let rw = this.tb.insertRow(this.tb.rows.length - n);
        //rw.style.height = this.row_h + "px";
        let self = this;
        [2, 90, 8].forEach(function (v, i) {
            let cl = rw.insertCell(i);
            if (i > 0) {
                cl.innerHTML = hs && hs[i - 1] || '';
            }
            if(i===2){
               cl.innerHTML =  cl.innerHTML === '' && self.last_cb ? self.last_cb():'';
            }
            cl.style.width = v + "%";
            cl.style.wordWrap = "break-word";
        });
        //still bottom
        let _sh = this.tdm.scrollHeight || 1;
        let _dh = $(this.tdm).height();
        let _fh = this.tdm.scrollTop;
        if (_fh + _dh + 100 > _sh) {
            this.tdm.scrollTop = _sh;
        }
        cb && cb(rw);
        return rw;
    }

    echo(m) {
            this.insertLine([m])
        }
}


//行为单位
class Row {

}

$.fn.extend({
    Xterm: function (cf, cb) {
        log(">>>>Table Init");
        let xtm = new Xterm(this);
        xtm.prompt = cf.prompt;
        xtm.cb = cb;
        return xtm;
    },
    log: function (m) {
        console.log(m)
    }
});

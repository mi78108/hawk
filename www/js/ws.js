class wsExt {
    constructor(url) {
        this.re_try = 5;
        this.url = url;
        this.ws = new WebSocket(this.url);
    }

    reconnect() {
        let ws = new WebSocket(this.url);
        ws.onopen = this.ws.onopen;
        ws.onclose = this.ws.onclose;
        ws.onerror = this.ws.onerror;
        ws.onmessage = this.ws.onmessage;
        this.ws = ws;
    }
}
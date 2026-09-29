# External Client Demo

Open `index.html` in a browser. Enable **Preferences → Plug-ins → ReaWebAPI → External Clients** in REAPER, apply the settings and copy the token into the Demo.

The Demo uses browser WebSocket APIs without a framework, build step, Lua launcher, ReaWebAPI WebView or JavaScript Mirror. It exercises authentication, capability queries, Native API calls, Batch, Native Events, `runtime.getInfo` and existing binary streams. A stream producer must register the requested name before **Open stream** can succeed. The token is kept in memory and is never included in the control URL.

Disconnect closes this session's subscriptions, pending invokes, handles and stream consumers. Other clients and existing WebView apps remain connected.

直接在浏览器打开 `index.html`。在 REAPER 的 **Preferences → Plug-ins → ReaWebAPI → External Clients** 中启用服务并应用设置，将 Token 复制到 Demo。

Demo 使用浏览器标准 WebSocket，不需要构建、Lua 启动器、ReaWebAPI WebView 或 JavaScript Mirror。打开 Stream 前，必须有原生 Producer 注册对应名称。断开只释放当前 Session 的资源。

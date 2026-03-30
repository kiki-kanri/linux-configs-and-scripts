server {
    # Include configs
    include public/headers/default.conf;
    include public/ssls/example.conf;

    # Server name
    server_name server_name;

    # Locations
    location / {
        include public/proxies/websocket.conf;
        proxy_pass http://127.0.0.1:3000;
    }
}

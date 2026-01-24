FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y \
        supervisor \
        tar \
        curl \
        wget \
        ncdu \
        nano \
        unzip \
        lib32gcc-s1 lib32stdc++6 bc && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN apt-get update && \
    apt-get remove -y systemd systemd-sysv && \
    apt-get autoremove -y && \
    apt-get install -y supervisor nginx && \
    mkdir -p /var/log/supervisor && \
    mkdir -p /root/cstrike

COPY install.sh /install.sh
RUN chmod +x /install.sh   

RUN rm -f /etc/nginx/sites-enabled/default && \
    rm -f /etc/nginx/sites-available/default

RUN cat << 'EOF' > /etc/nginx/conf.d/fastdl.conf
server {
    listen 6789;
    server_name _;

    root /root/cstrike;

    location ~ ^/(maps|models|sound|sprites|gfx|overviews)/ {
        autoindex on;
    }

    location ^~ /banner/ {
        alias /root/cstrike/banner/;
        autoindex on;
    }

    location / {
        return 404;
    }
}
EOF

RUN cat << 'EOF' > /etc/supervisor/conf.d/cs.conf
[program:cs]
directory=/root
command=/root/start-line
autostart=true
autorestart=true
exitcodes=0
stopasgroup=true
killasgroup=true
stdout_logfile=/var/log/cs.out.log
stderr_logfile=/var/log/cs.err.log
redirect_stderr=true
EOF

RUN cat << 'EOF' > /etc/supervisor/conf.d/fastdl.conf
[program:fastdl]
command=/usr/sbin/nginx -g "daemon off;"
autostart=true
autorestart=true
stdout_logfile=/var/log/nginx.out.log
stderr_logfile=/var/log/nginx.err.log
EOF

CMD ["/usr/bin/supervisord", "-n"] 


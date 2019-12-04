# haproxy2.1.0 with certbot
FROM debian:buster AS BUILDER

RUN apt-get update && apt-get install -q -y libssl1.1 libpcre3 --no-install-recommends && rm -rf /var/lib/apt/lists/*

# Setup HAProxy
ENV HAPROXY_MAJOR 2.1
ENV HAPROXY_VERSION 2.1.0
RUN buildDeps='curl gcc libc6-dev libpcre3-dev libssl-dev make zlib1g zlib1g-dev' \
  && set -x \
  && apt-get update && apt-get install -y $buildDeps --no-install-recommends && rm -rf /var/lib/apt/lists/*
RUN echo "building HAPROXY now ..." \
  && curl -SL "http://www.haproxy.org/download/${HAPROXY_MAJOR}/src/haproxy-${HAPROXY_VERSION}.tar.gz" -o haproxy.tar.gz \
  && mkdir -p /usr/src/haproxy \
  && tar -xzf haproxy.tar.gz -C /usr/src/haproxy --strip-components=1 \
  && rm haproxy.tar.gz \
  && make -C /usr/src/haproxy \
  TARGET=linux-glibc \
  USE_PCRE=1 PCREDIR= \
  USE_OPENSSL=1 \
  USE_ZLIB=1 \
  all \
  install-bin \
  && mkdir -p /config \
  && mkdir -p /usr/local/etc/haproxy \
  && cp -R /usr/src/haproxy/examples/errorfiles /usr/local/etc/haproxy/errors \
  && rm -rf /usr/src/haproxy \
  && apt-get purge -y --auto-remove $buildDeps

# Install Supervisor, cron, libnl-utils, net-tools, iptables
RUN apt-get -q update && apt-get install -q -y supervisor cron libnl-utils net-tools iptables \
  && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN update-alternatives --set iptables /usr/sbin/iptables-legacy \
  && update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

# Install Certbot
RUN echo 'deb http://ftp.debian.org/debian buster-backports main' > /etc/apt/sources.list.d/buster-backports.list
RUN apt-get -q update && apt-get install -q -y certbot -t buster-backports && \
  apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# todo: create a chained build / image without above overhead
# FROM debian:buster AS Final

# Setup Supervisor
RUN mkdir -p /var/log/supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Setup Certbot
RUN mkdir -p /usr/local/etc/haproxy/certs.d \
  && mkdir -p /usr/local/etc/letsencrypt
COPY certbot.cron /etc/cron.d/certbot
COPY cli.ini /usr/local/etc/letsencrypt/cli.ini
COPY haproxy-refresh.sh /usr/bin/haproxy-refresh
COPY haproxy-restart.sh /usr/bin/haproxy-restart
COPY certbot-certonly.sh /usr/bin/certbot-certonly
COPY certbot-renew.sh /usr/bin/certbot-renew
# Add startup script
COPY start.sh /start.sh

RUN chmod +x /usr/bin/haproxy-refresh /usr/bin/haproxy-restart /usr/bin/certbot-certonly /usr/bin/certbot-renew /start.sh

# Start
CMD bash -x /start.sh

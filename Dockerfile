# docker build . -t docker-rslsync --platform linux/amd64

FROM --platform=linux/amd64 debian:stable-slim AS build_amd64

ADD https://download-cdn.resilio.com/stable/linux/x64/0/resilio-sync_x64.tar.gz /tmp

FROM build_${TARGETARCH} AS build

RUN apt-get update \
    && apt-get install -y runit \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /rslsync \
    && tar xf /tmp/resilio-sync*.tar.gz -C /rslsync \
    && mkdir -p /mnt/sync/config /mnt/sync/folders

RUN mkdir -p /etc/service/rslsync \
    && echo '#!/bin/sh\nexec /rslsync/rslsync --nodaemon --config /mnt/sync/sync.conf' \
       > /etc/service/rslsync/run \
    && chmod +x /etc/service/rslsync/run

RUN echo '#!/bin/bash\n\
\n\
shutdown() {\n\
    sv -w 10 force-stop /etc/service/*\n\
    sv exit /etc/service/*\n\
    exit 0\n\
}\n\
\n\
trap shutdown SIGINT SIGTERM\n\
\n\
if ! [ -f /mnt/sync/sync.conf ]; then\n\
    /rslsync/rslsync --dump-sample-config > /mnt/sync/sync.conf;\n\
fi\n\
\n\
runsvdir -P /etc/service &\n\
wait $!' > /usr/local/bin/runit.sh \
    && chmod +x /usr/local/bin/runit.sh

VOLUME ["/mnt/sync"]

EXPOSE 8888/tcp
EXPOSE 55555/tcp
EXPOSE 55555/udp

ENTRYPOINT ["/usr/local/bin/runit.sh"]

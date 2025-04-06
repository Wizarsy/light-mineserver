FROM alpine:latest

ENV SERVER_VERSION=latest-mojang
ENV CANDIDATES_FILE="https://raw.githubusercontent.com/Wizarsy/mine_servers/main/servers.json"
ENV AUTOBACKUP=900
ENV JVM_ARGS="-Xms2G -Xmx2G"
ENV SERVER_ARGS="nogui"
ENV TZ=Brazil/East

RUN apk add --no-cache ca-certificates tzdata jq curl bash

COPY ./entrypoint.sh /
RUN chmod +x /entrypoint.sh

WORKDIR /mineserver

EXPOSE 25565/tcp
EXPOSE 25565/udp

ENTRYPOINT [ "/bin/bash", "-c", "/entrypoint.sh" ]
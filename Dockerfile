FROM alpine:latest

ENV MINE_VERSION=latest-mojang
ENV ONLINE_CANDIDATES="https://raw.githubusercontent.com/Wizarsy/mine_servers/main/servers.json"
ENV LOCAL_CANDIDATES=
ENV AUTOSAVE=900

ENV ONLINE=true
ENV GAMEMODE=survival
ENV DIFFICULTY=normal
ENV SEED=
ENV MAX_PLAYERS=10
ENV PVP=true
ENV MOTD="A Minecraft Server"
ENV VIEW_DISTANCE=10
ENV SIMULATION_DISTANCE=10

ENV XMX=1G

ENV TZ=Brazil/East

RUN apk add --no-cache ca-certificates tzdata jq curl bash

COPY ./entrypoint.sh /
RUN chmod +x /entrypoint.sh

WORKDIR /mineserver

EXPOSE 25565/tcp
EXPOSE 25565/udp

ENTRYPOINT [ "/bin/bash", "-c", "/entrypoint.sh" ]
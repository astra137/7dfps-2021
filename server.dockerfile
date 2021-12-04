FROM frolvlad/alpine-glibc:latest as godot-server
ADD https://downloads.tuxfamily.org/godotengine/3.4/Godot_v3.4-stable_linux_server.64.zip /tmp/godot.zip
RUN unzip /tmp/godot.zip -d /usr/local/bin/ && mv /usr/local/bin/Godot* /usr/local/bin/godot
RUN mkdir ~/.cache && mkdir -p ~/.config/godot

FROM godotimages/godot:3.4 as build
COPY . /build
RUN godot --path /build --export-pack Docker game.pck

FROM godot-server as app
LABEL org.opencontainers.image.source https://github.com/astra137/7dfps-2021
EXPOSE 10567/udp
VOLUME [ "/data" ]
RUN apk add --no-cache tini
COPY --from=build /build/game.pck /app/
WORKDIR /data
CMD [ "godot", "--main-pack", "/app/game.pck" ]
ENTRYPOINT ["tini", "--"]

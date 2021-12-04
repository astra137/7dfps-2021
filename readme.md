# 7dfps-2021

> https://itch.io/jam/7dfps-2021

## Dedicated Server

```shell
docker build -f server.dockerfile -t fps .
docker run -it --rm -p 10567:10567/udp fps
```

#!/bin/bash

read -p "USERNAME: " USERNAME
read -p "HOST: " HOST
read -p "EMAIL: " EMAIL
read -sp "ADMIN_PASSWORD: " ADMIN_PASSWORD
HASHED_PASSWORD=$(openssl passwd -apr1 $ADMIN_PASSWORD)


# create public network
docker network create --driver=overlay traefik-public

# create public certs volumes
docker volume create traefik-public-certificates

# tag the node
NODE_ID=$(docker info -f '{{.Swarm.NodeID}}')
docker node update --label-add traefik-public.traefik-public-certificates=true ${NODE_ID}

# create service
docker service create \
    --name traefik \
    --constraint=node.labels.traefik-public.traefik-public-certificates==true \
    --publish 80:80 \
    --publish 443:443 \
    --mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock \
    --mount type=volume,source=traefik-public-certificates,target=/certificates \
    --network traefik-public \
    --label "traefik.frontend.rule=Host:traefik.$HOST" \
    --label "traefik.enable=true" \
    --label "traefik.port=8080" \
    --label "traefik.tags=traefik-public" \
    --label "traefik.docker.network=traefik-public" \
    --label "traefik.redirectorservice.frontend.entryPoints=http" \
    --label "traefik.redirectorservice.frontend.redirect.entryPoint=https" \
    --label "traefik.webservice.frontend.entryPoints=https" \
    --label "traefik.frontend.auth.basic.users=${USERNAME}:${HASHED_PASSWORD}" \
    traefik:v1.7 \
    --docker \
    --docker.swarmmode \
    --docker.watch \
    --docker.exposedbydefault=false \
    --constraints=tag==traefik-public \
    --entrypoints='Name:http Address::80' \
    --entrypoints='Name:https Address::443 TLS' \
    --acme \
    --acme.email=$EMAIL \
    --acme.storage=/certificates/acme.json \
    --acme.entryPoint=https \
    --acme.httpChallenge.entryPoint=http\
    --acme.onhostrule=true \
    --acme.acmelogging=true \
    --logLevel=INFO \
    --accessLog \
    --api
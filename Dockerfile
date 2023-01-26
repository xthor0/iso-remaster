# TODO: change this to Rocky so we can use ksvalidator
FROM debian:bullseye-slim

RUN apt update && apt-get install --no-install-recommends --yes isolinux p7zip-full xorriso curl wget ca-certificates tzdata && apt-get dist-upgrade --yes && rm -rf /var/lib/apt/lists/*
ENV TZ="America/Denver"

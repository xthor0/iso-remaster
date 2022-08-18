FROM debian:bullseye-slim

RUN apt update && apt-get install --no-install-recommends --yes isolinux p7zip-full xorriso curl wget ca-certificates && apt-get dist-upgrade --yes && rm -rf /var/lib/apt/lists/*

# NOTE: This will *NOT* run on aarch64 architectures.
# syslinux does not exist as a package when run on aarch64.
FROM docker.io/library/debian:12-slim
RUN apt update && apt-get install --no-install-recommends --yes isolinux p7zip-full xorriso curl wget ca-certificates tzdata && apt-get dist-upgrade --yes && rm -rf /var/lib/apt/lists/*
ENV TZ="America/Denver"

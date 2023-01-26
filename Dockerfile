# NOTE: This will *NOT* run on aarch64 architectures.
# syslinux does not exist as a package when run on aarch64.
FROM rockylinux:9
RUN dnf install -y epel-release \
    && dnf install -y syslinux xorriso wget p7zip-plugins which diffutils pykickstart \
  	&& dnf clean all \
  	&& rm -rf /var/cache/yum
ENV TZ="America/Denver"
# Tooling to build a Rocky Linux or Debian Automated ISO

I have several physical machines that I use as libvirt hosts. And I want to automate ALL. THE. THINGS.

So, I built some tooling to do that.

Just install [podman](https://podman.io/), check out the code, and execute `./run.sh -t debian` (or `rocky`).

## NOTE
If you've stumbled across this from the broader interwebz, turns out there's a much easier way of doing this.

https://weldr.io/lorax/mkksiso.html

It has to be run on RHEL or a derivative (CentOS, Rocky Linux, Fedora to name a few).
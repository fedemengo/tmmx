FROM ubuntu:24.04

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends openssh-server tmux netcat-openbsd && rm -rf /var/lib/apt/lists/*
RUN useradd --create-home --shell /usr/local/bin/noisy-shell tmmx && mkdir -p /run/sshd /home/tmmx/.ssh && chown -R tmmx:tmmx /home/tmmx/.ssh
COPY noisy-shell /usr/local/bin/noisy-shell
COPY entrypoint.sh /usr/local/bin/tmmx-e2e-host
RUN chmod 755 /usr/local/bin/noisy-shell /usr/local/bin/tmmx-e2e-host

EXPOSE 22
ENTRYPOINT ["/usr/local/bin/tmmx-e2e-host"]

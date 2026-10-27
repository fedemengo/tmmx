FROM ubuntu:24.04

# A believable demo host: sshd + tmux, with a normal login shell so seeded
# sessions behave like a real box. fzf is included so that, if you also install
# tmmx on the host, the forwarded per-host pickers render here too.
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      openssh-server tmux fzf netcat-openbsd && rm -rf /var/lib/apt/lists/*
RUN useradd --create-home --shell /bin/bash tmmx \
    && mkdir -p /run/sshd /home/tmmx/.ssh \
    && chown -R tmmx:tmmx /home/tmmx/.ssh
COPY seed.sh /usr/local/bin/tmmx-demo-seed
COPY entrypoint.sh /usr/local/bin/tmmx-demo-host
RUN chmod 755 /usr/local/bin/tmmx-demo-seed /usr/local/bin/tmmx-demo-host

EXPOSE 22
ENTRYPOINT ["/usr/local/bin/tmmx-demo-host"]

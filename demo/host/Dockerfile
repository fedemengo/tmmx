FROM ubuntu:24.04

# A believable demo host: sshd + tmux, with a normal login shell so seeded
# sessions behave like a real box. fzf + tmmx give the forwarded per-host pickers;
# minova themes the status bar so you can see which host/session you're on.
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      openssh-server tmux fzf netcat-openbsd git ca-certificates && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 https://github.com/fedemengo/tmux-minova /opt/minova
RUN useradd --create-home --shell /bin/bash tmmx \
    && mkdir -p /run/sshd /home/tmmx/.ssh \
    && chown -R tmmx:tmmx /home/tmmx/.ssh
COPY host-tmux.conf /home/tmmx/.tmux.conf
COPY seed.sh /usr/local/bin/tmmx-demo-seed
COPY entrypoint.sh /usr/local/bin/tmmx-demo-host
RUN chown tmmx:tmmx /home/tmmx/.tmux.conf \
    && chmod 644 /home/tmmx/.tmux.conf \
    && chmod 755 /usr/local/bin/tmmx-demo-seed /usr/local/bin/tmmx-demo-host

EXPOSE 22
ENTRYPOINT ["/usr/local/bin/tmmx-demo-host"]

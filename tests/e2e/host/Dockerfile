FROM ubuntu:24.04

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends openssh-server tmux netcat-openbsd && rm -rf /var/lib/apt/lists/*
RUN useradd --create-home --shell /usr/local/bin/noisy-shell tmmx && mkdir -p /run/sshd /home/tmmx/.ssh && chown -R tmmx:tmmx /home/tmmx/.ssh
COPY noisy-shell /usr/local/bin/noisy-shell
COPY entrypoint.sh /usr/local/bin/tmmx-e2e-host
COPY restore.sh /usr/local/bin/tmmx-e2e-restore
RUN printf '%s\n' "set -g @resurrect-restore-script-path '/usr/local/bin/tmmx-e2e-restore'" > /home/tmmx/.tmux.conf && chown tmmx:tmmx /home/tmmx/.tmux.conf && chmod 755 /usr/local/bin/noisy-shell /usr/local/bin/tmmx-e2e-host /usr/local/bin/tmmx-e2e-restore

EXPOSE 22
ENTRYPOINT ["/usr/local/bin/tmmx-e2e-host"]

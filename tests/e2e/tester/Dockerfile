FROM ubuntu:24.04

ENV TERM=xterm-256color

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends openssh-client tmux fzf util-linux coreutils && rm -rf /var/lib/apt/lists/*
COPY test.sh /usr/local/bin/tmmx-e2e-test
COPY fzf-flow /usr/local/bin/tmmx-e2e-fzf-flow
RUN chmod 755 /usr/local/bin/tmmx-e2e-test /usr/local/bin/tmmx-e2e-fzf-flow

ENTRYPOINT ["/usr/local/bin/tmmx-e2e-test"]

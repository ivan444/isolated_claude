FROM node:trixie

ARG USERNAME
ARG USER_UID
ARG USER_GID

RUN set -eu; \
  : "${USERNAME:?Build arg USERNAME is required (e.g. --build-arg USERNAME=\$USER)}" \
    "${USER_UID:?Build arg USER_UID is required (e.g. --build-arg USER_UID=\$(id -u))}" \
    "${USER_GID:?Build arg USER_GID is required (e.g. --build-arg USER_GID=\$(id -g))}"

# Change the group and user ID of the "node" user to high value to avoid
# collisions with the real (local) users.
RUN groupmod -o -g 1500 node \
 && usermod  -o -u 1500 -g 1500 node \
 && chown -R node:node /home/node

# Add matching real user so the container can write the files with matching
# ownership on the host.
RUN groupadd --gid ${USER_GID} ${USERNAME}
RUN useradd --uid ${USER_UID} --gid ${USER_GID} -m -s /bin/bash ${USERNAME}

RUN apt update
RUN apt install -y --no-install-recommends bash ca-certificates git sudo ripgrep

# Give sudo to the user running this container -- enable installing software
# without running as root.
RUN echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME}
RUN chmod 0440 /etc/sudoers.d/${USERNAME}

RUN npm install -g @anthropic-ai/claude-code

WORKDIR /workspace
ENTRYPOINT ["claude"]


# Base docker file having defined environment for build and run of HAF instance.
# docker buildx build --progress=plain --target=ci-base-image --tag registry.gitlab.syncad.com/hive/haf/ci-base-image$CI_IMAGE_TAG --file Dockerfile .
# To be started from cloned haf source directory.
ARG CI_REGISTRY_IMAGE=registry.gitlab.syncad.com/hive/haf/
ARG CI_IMAGE_TAG=ubuntu22.04-8

ARG BUILD_IMAGE_TAG

FROM registry.gitlab.syncad.com/hive/hive/minimal-runtime:ubuntu22.04-10 AS minimal-runtime

ENV PATH="/home/haf_admin/.local/bin:$PATH"

SHELL ["/bin/bash", "-c"]

USER root
WORKDIR /usr/local/src
COPY ./hive/scripts/openssl.conf /usr/local/src/hive/scripts/openssl.conf
COPY ./hive/scripts/setup_ubuntu.sh /usr/local/src/hive/scripts/
COPY ./scripts/setup_ubuntu.sh /usr/local/src/scripts/

# create required accounts
RUN ./scripts/setup_ubuntu.sh --haf-admin-account="haf_admin" --hived-account="hived" && rm -rf /var/lib/apt/lists/*
# install postgres.  Installation automatically does an initdb, so remove the 29+MB database that we don't need afterwards
RUN apt-get update && \
    DEBIAN_FRONTEND=noniteractive apt-get install --no-install-recommends -y curl postgresql libpq5 libboost-chrono1.74.0 libboost-context1.74.0 libboost-filesystem1.74.0 libboost-thread1.74.0 && \
    rm -rf /var/lib/postgresql/14/main /var/lib/apt/lists/*
# change the UID and GID to match the ones postgres is assigned in our non-minimal runtime
RUN (chown -Rf --from=postgres 105 / || true) && (chown -Rf --from=:postgres :109 / || true) && usermod -u 105 postgres && groupmod -g 109 postgres
RUN usermod -a -G users -c "PostgreSQL daemon account" postgres

USER haf_admin
WORKDIR /home/haf_admin

FROM registry.gitlab.syncad.com/hive/hive/ci-base-image:ubuntu22.04-10 AS ci-base-image

ENV PATH="/home/haf_admin/.local/bin:$PATH"

SHELL ["/bin/bash", "-c"]

USER root
WORKDIR /usr/local/src
COPY ./hive/scripts/openssl.conf /usr/local/src/hive/scripts/openssl.conf
COPY ./hive/scripts/setup_ubuntu.sh /usr/local/src/hive/scripts/
COPY ./scripts/setup_ubuntu.sh /usr/local/src/scripts/

# Install development packages and create required accounts
RUN ./scripts/setup_ubuntu.sh --dev --haf-admin-account="haf_admin" --hived-account="hived" \
  && rm -rf /var/lib/apt/lists/*

USER haf_admin
WORKDIR /home/haf_admin

# Install additionally packages located in user directory
RUN /usr/local/src/scripts/setup_ubuntu.sh --user

FROM ${CI_REGISTRY_IMAGE}ci-base-image:$CI_IMAGE_TAG AS build

ARG BUILD_HIVE_TESTNET=OFF
ENV BUILD_HIVE_TESTNET=${BUILD_HIVE_TESTNET}

ARG ENABLE_SMT_SUPPORT=OFF
ENV ENABLE_SMT_SUPPORT=${ENABLE_SMT_SUPPORT}

ARG HIVE_CONVERTER_BUILD=OFF
ENV HIVE_CONVERTER_BUILD=${HIVE_CONVERTER_BUILD}

ARG HIVE_LINT=OFF
ENV HIVE_LINT=${HIVE_LINT}

ARG HIVE_SUBDIR=.
ENV HIVE_SUBDIR=${HIVE_SUBDIR}

ENV HAF_SOURCE_DIR="/home/haf_admin/source/${HIVE_SUBDIR}"

USER haf_admin
WORKDIR /home/haf_admin

SHELL ["/bin/bash", "-c"]

# Get everything from cwd as sources to be built.
COPY --chown=haf_admin:users . /home/haf_admin/source

RUN \
  "${HAF_SOURCE_DIR}/scripts/build.sh" --haf-source-dir="${HAF_SOURCE_DIR}" --haf-binaries-dir="./build" \
  --cmake-arg="-DBUILD_HIVE_TESTNET=${BUILD_HIVE_TESTNET}" \
  --cmake-arg="-DENABLE_SMT_SUPPORT=${ENABLE_SMT_SUPPORT}" \
  --cmake-arg="-DHIVE_CONVERTER_BUILD=${HIVE_CONVERTER_BUILD}" \
  --cmake-arg="-DHIVE_LINT=${HIVE_LINT}" \
  && \
  cd ./build && \
  find . -name *.o  -type f -delete && \
  find . -name *.a  -type f -delete

# Here we could use a smaller image without packages specific to build requirements
FROM ${CI_REGISTRY_IMAGE}ci-base-image:$CI_IMAGE_TAG as base_instance

ENV BUILD_IMAGE_TAG=${BUILD_IMAGE_TAG:-:ubuntu22.04-8}

ARG P2P_PORT=2001
ENV P2P_PORT=${P2P_PORT}

ARG WS_PORT=8090
ENV WS_PORT=${WS_PORT}

ARG HTTP_PORT=8091
ENV HTTP_PORT=${HTTP_PORT}

ARG HIVE_SUBDIR=.
ENV HIVE_SUBDIR=${HIVE_SUBDIR}

ENV HAF_SOURCE_DIR="/home/haf_admin/source/${HIVE_SUBDIR}"

# Environment variable which allows to override default postgres access specification in pg_hba.conf
ENV PG_ACCESS="host    haf_block_log     haf_app_admin    172.0.0.0/8    trust\nhost    all     pghero    172.0.0.0/8    trust"

# Always define default value of HIVED_UID variable to make possible direct spawn of docker image (without run_hived_img.sh wrapper)
ENV HIVED_UID=1000

SHELL ["/bin/bash", "-c"]

USER hived
WORKDIR /home/hived

RUN mkdir -p /home/hived/bin && \
    mkdir /home/hived/shm_dir && \
    mkdir /home/hived/datadir && \
    chown -Rc hived:users /home/hived/

COPY --from=build --chown=hived:users \
  /home/haf_admin/build/hive/programs/hived/hived \
  /home/haf_admin/build/hive/programs/cli_wallet/cli_wallet \
  /home/haf_admin/build/hive/programs/util/* \
  /home/haf_admin/build/hive/programs/blockchain_converter/blockchain_converter* \
  /home/haf_admin/build/tests/unit/* \
  /home/hived/bin/

USER haf_admin
WORKDIR /home/haf_admin

COPY --from=build --chown=haf_admin:users /home/haf_admin/build /home/haf_admin/build/
COPY --from=build --chown=haf_admin:users "${HAF_SOURCE_DIR}" "${HAF_SOURCE_DIR}"

ENV POSTGRES_VERSION=14
COPY --from=build --chown=haf_admin:users "${HAF_SOURCE_DIR}/docker/docker_entrypoint.sh" .
COPY --from=build --chown=postgres:postgres "${HAF_SOURCE_DIR}/docker/postgresql.conf" /etc/postgresql/$POSTGRES_VERSION/main/postgresql.conf
COPY --from=build --chown=postgres:postgres "${HAF_SOURCE_DIR}/docker/pg_hba.conf" /etc/postgresql/$POSTGRES_VERSION/main/pg_hba.conf.default

ENV DATADIR=/home/hived/datadir
# Use default location (inside datadir) of shm file. If SHM should be placed on some different device, then set it to mapped volume `/home/hived/shm_dir` and map it in docker run
ENV SHM_DIR=${DATADIR}/blockchain

STOPSIGNAL SIGINT

# JSON rpc service
EXPOSE ${HTTP_PORT}

ENTRYPOINT [ "/home/haf_admin/docker_entrypoint.sh" ]

ARG BUILD_TIME
ARG GIT_COMMIT_SHA
ARG GIT_CURRENT_BRANCH
ARG GIT_LAST_LOG_MESSAGE
ARG GIT_LAST_COMMITTER
ARG GIT_LAST_COMMIT_DATE
LABEL org.opencontainers.image.created="$BUILD_TIME"
LABEL org.opencontainers.image.url="https://hive.io/"
LABEL org.opencontainers.image.documentation="https://gitlab.syncad.com/hive/haf"
LABEL org.opencontainers.image.source="https://gitlab.syncad.com/hive/haf"
#LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.revision="$GIT_COMMIT_SHA"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.ref.name="HAF Core"
LABEL org.opencontainers.image.title="Hive Application Framework (HAF) Core Image"
LABEL org.opencontainers.image.description="Runs both the PostgreSQL database server and the hived instance that feeds it blockchain data"
LABEL io.hive.image.branch="$GIT_CURRENT_BRANCH"
LABEL io.hive.image.commit.log_message="$GIT_LAST_LOG_MESSAGE"
LABEL io.hive.image.commit.author="$GIT_LAST_COMMITTER"
LABEL io.hive.image.commit.date="$GIT_LAST_COMMIT_DATE"

FROM ${CI_REGISTRY_IMAGE}base_instance:${BUILD_IMAGE_TAG} as instance

# Embedded postgres service
EXPOSE 5432

EXPOSE ${P2P_PORT}
# websocket service
EXPOSE ${WS_PORT}
# JSON rpc service
EXPOSE ${HTTP_PORT}

FROM registry.gitlab.syncad.com/hive/haf/minimal-runtime:ubuntu22.04-10 AS minimal-instance

ENV BUILD_IMAGE_TAG=${BUILD_IMAGE_TAG:-:ubuntu22.04-8}

ARG P2P_PORT=2001
ENV P2P_PORT=${P2P_PORT}

ARG WS_PORT=8090
ENV WS_PORT=${WS_PORT}

ARG HTTP_PORT=8091
ENV HTTP_PORT=${HTTP_PORT}

ARG HIVE_SUBDIR=.
ENV HIVE_SUBDIR=${HIVE_SUBDIR}

ENV HAF_SOURCE_DIR="/home/haf_admin/source/${HIVE_SUBDIR}"

# Environment variable which allows to override default postgres access specification in pg_hba.conf
ENV PG_ACCESS="host    haf_block_log     haf_app_admin    172.0.0.0/8    trust\nhost    all     pghero    172.0.0.0/8    trust"

# Always define default value of HIVED_UID variable to make possible direct spawn of docker image (without run_hived_img.sh wrapper)
ENV HIVED_UID=1000

ENV POSTGRES_VERSION=14

SHELL ["/bin/bash", "-c"]

USER hived
WORKDIR /home/hived

RUN mkdir -p /home/hived/bin && \
    mkdir /home/hived/shm_dir && \
    mkdir /home/hived/datadir && \
    chown -Rc hived:users /home/hived/

COPY --from=build --chown=hived:users \
  /home/haf_admin/build/hive/programs/hived/hived \
  /home/haf_admin/build/hive/programs/cli_wallet/cli_wallet \
  /home/haf_admin/build/hive/programs/util/compress_block_log \
  /home/hived/bin/

COPY --from=build \
  /home/haf_admin/build/extensions/hive_fork_manager/* \
  /usr/share/postgresql/${POSTGRES_VERSION}/extension

COPY --from=build \
  /home/haf_admin/build/lib/libquery_supervisor.so \
  /usr/lib/postgresql/${POSTGRES_VERSION}/lib
COPY --from=build \
  /home/haf_admin/build/lib/libhfm-* \
  /usr/lib/postgresql/${POSTGRES_VERSION}/lib
# set a variable telling the entrypoint not to try to install the extension from source, we just did it above
ENV HAF_INSTALL_EXTENSION=no

USER haf_admin
WORKDIR /home/haf_admin

COPY --from=build --chown=haf_admin:users "${HAF_SOURCE_DIR}/docker/docker_entrypoint.sh" .
RUN mkdir -p /home/haf_admin/source/scripts /home/haf_admin/source/hive/scripts && chown -R haf_admin:users /home/haf_admin/source
COPY --from=build --chown=haf_admin:users "${HAF_SOURCE_DIR}/scripts/" /home/haf_admin/source/scripts
COPY --from=build --chown=haf_admin:users "${HAF_SOURCE_DIR}/hive/scripts/" /home/haf_admin/source/hive/scripts
COPY --from=build --chown=postgres:postgres "${HAF_SOURCE_DIR}/docker/postgresql.conf" /etc/postgresql/$POSTGRES_VERSION/main/postgresql.conf
COPY --from=build --chown=postgres:postgres "${HAF_SOURCE_DIR}/docker/pg_hba.conf" /etc/postgresql/$POSTGRES_VERSION/main/pg_hba.conf.default

ENV DATADIR=/home/hived/datadir
# Use default location (inside datadir) of shm file. If SHM should be placed on some different device, then set it to mapped volume `/home/hived/shm_dir` and map it in docker run
ENV SHM_DIR=${DATADIR}/blockchain

STOPSIGNAL SIGINT

# JSON rpc service
EXPOSE ${HTTP_PORT}

ENTRYPOINT [ "/home/haf_admin/docker_entrypoint.sh" ]

ARG BUILD_TIME
ARG GIT_COMMIT_SHA
ARG GIT_CURRENT_BRANCH
ARG GIT_LAST_LOG_MESSAGE
ARG GIT_LAST_COMMITTER
ARG GIT_LAST_COMMIT_DATE
LABEL org.opencontainers.image.created="$BUILD_TIME"
LABEL org.opencontainers.image.url="https://hive.io/"
LABEL org.opencontainers.image.documentation="https://gitlab.syncad.com/hive/haf"
LABEL org.opencontainers.image.source="https://gitlab.syncad.com/hive/haf"
#LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.revision="$GIT_COMMIT_SHA"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.ref.name="HAF Core"
LABEL org.opencontainers.image.title="Hive Application Framework (HAF) Core Image"
LABEL org.opencontainers.image.description="Runs both the PostgreSQL database server and the hived instance that feeds it blockchain data"
LABEL io.hive.image.branch="$GIT_CURRENT_BRANCH"
LABEL io.hive.image.commit.log_message="$GIT_LAST_LOG_MESSAGE"
LABEL io.hive.image.commit.author="$GIT_LAST_COMMITTER"
LABEL io.hive.image.commit.date="$GIT_LAST_COMMIT_DATE"

# Base docker file having defined environment for build and run of HAF instance.
# docker build --target=ci-base-image -t registry.gitlab.syncad.com/hive/haf/ci-base-image:ubuntu20.04-xxx -f Dockerfile .
# To be started from cloned haf source directory.
ARG CI_REGISTRY_IMAGE=registry.gitlab.syncad.com/hive/haf/
ARG CI_IMAGE_TAG=:ubuntu20.04-6 

ARG BLOCK_LOG_SUFFIX
ARG NETWORK_TYPE

ARG BUILD_IMAGE_TAG

FROM phusion/baseimage:focal-1.0.0 AS ci-base-image

ENV LANG=en_US.UTF-8

SHELL ["/bin/bash", "-c"] 

USER root
WORKDIR /usr/local/src
ADD ./scripts/setup_ubuntu.sh /usr/local/src/scripts/

RUN ./scripts/setup_ubuntu.sh --haf-admin-account="haf_admin" --hived-account="hived"

USER hived
WORKDIR /home/hived

RUN git clone --depth 1 --branch master https://github.com/wolfcw/libfaketime.git \
    && cd libfaketime && make

USER haf_admin
WORKDIR /home/haf_admin

#docker build --target=ci-base-image-5m -t registry.gitlab.syncad.com/hive/haf/ci-base-image-5m:ubuntu20.04-xxx -f Dockerfile .
FROM ${CI_REGISTRY_IMAGE}ci-base-image$CI_IMAGE_TAG AS ci-base-image-5m

RUN sudo -n mkdir -p /home/hived/block_log_5m && cd /home/hived/block_log_5m && \
  sudo -n wget -c https://gtg.openhive.network/get/blockchain/block_log.5M && \
    sudo -n mv block_log.5M block_log && sudo -n chown -Rc hived:hived /home/hived/block_log_5m/

FROM ${CI_REGISTRY_IMAGE}ci-base-image$CI_IMAGE_TAG AS build

ARG BUILD_HIVE_TESTNET=OFF
ENV BUILD_HIVE_TESTNET=${BUILD_HIVE_TESTNET}

ARG HIVE_CONVERTER_BUILD=OFF
ENV HIVE_CONVERTER_BUILD=${HIVE_CONVERTER_BUILD}

ARG HIVE_LINT=OFF
ENV HIVE_LINT=${HIVE_LINT}

USER haf_admin
WORKDIR /home/haf_admin

SHELL ["/bin/bash", "-c"] 

# Get everything from cwd as sources to be built.
COPY --chown=haf_admin:haf_admin . /home/haf_admin/haf

RUN \
  ./haf/scripts/build.sh --haf-source-dir="./haf" --haf-binaries-dir="./build" \
  --cmake-arg="-DBUILD_HIVE_TESTNET=${BUILD_HIVE_TESTNET}" \
  --cmake-arg="-DHIVE_CONVERTER_BUILD=${HIVE_CONVERTER_BUILD}" \
  --cmake-arg="-DHIVE_LINT=${HIVE_LINT}" \
  && \
  cd ./build && \
  find . -name *.o  -type f -delete && \
  find . -name *.a  -type f -delete

FROM ${CI_REGISTRY_IMAGE}ci-base-image$CI_IMAGE_TAG AS convert_block_log

USER hived
WORKDIR /home/hived

COPY --from=build \
    /home/haf_admin/build/hive/programs/blockchain_converter/blockchain_converter /home/hived/bin/

RUN mkdir /home/hived/block_log_5m

COPY --from=ci-base-image-5m \
    /home/hived/block_log_5m/block_log /home/hived/block_log_5m/block_log

RUN /home/hived/bin/blockchain_converter --plugin block_log_conversion \
    --input block_log_5m/block_log --output block_log_5m/new_fancy_block_log \
    --chain-id 1 --private-key 5JNHfZYKGaomSFvd4NUdQ9qMcEAC43kujbfjueTHpVapX1Kzq2n --use-same-key --jobs 2

#docker build --target=ci-base-image-mirrornet-5m -t registry.gitlab.syncad.com/hive/haf/ci-base-image-mirrornet-5m:ubuntu20.04-xxx -f Dockerfile .
FROM ${CI_REGISTRY_IMAGE}ci-base-image$CI_IMAGE_TAG AS ci-base-image-mirrornet-5m

USER hived

RUN mkdir /home/hived/block_log_5m

COPY --from=convert_block_log \
    /home/hived/block_log_5m/new_fancy_block_log /home/hived/block_log_5m/block_log

# Here we could use a smaller image without packages specific to build requirements
FROM ${CI_REGISTRY_IMAGE}ci-base-image${NETWORK_TYPE}${BLOCK_LOG_SUFFIX}$CI_IMAGE_TAG as instance

#ENV BUILD_IMAGE_TAG=${BUILD_IMAGE_TAG:-:ubuntu20.04-4}
ARG CONFIG_INI
ARG BLOCK_LOG_SUFFIX
ENV BLOCK_LOG_SUFFIX=${BLOCK_LOG_SUFFIX}
ARG NETWORK_TYPE
ENV NETWORK_TYPE=${NETWORK_TYPE}

ARG P2P_PORT=2001
ENV P2P_PORT=${P2P_PORT}
EXPOSE ${P2P_PORT}

ARG WS_PORT=8091
ENV WS_PORT=${WS_PORT}
EXPOSE ${WS_PORT}

ARG HTTP_PORT=8090
ENV HTTP_PORT=${HTTP_PORT}
EXPOSE ${HTTP_PORT}

ENV HAF_DB_STORE=/home/hived/datadir/haf_db_store
ENV PGDATA=/home/hived/datadir/haf_db_store/pgdata
# Environment variable which allows to override default postgres access specification in pg_hba.conf
ENV PG_ACCESS="\n"\
"host    haf_block_log     haf_app_admin    0.0.0.0/0     trust\n"\
"host    haf_block_log     haf_admin        0.0.0.0/0     trust\n"

SHELL ["/bin/bash", "-c"] 

USER hived
WORKDIR /home/hived

# TODO: remove this line after uploading regenerated images to container registry
RUN if [ -f /home/hived/datadir/blockchain/block_log ]; then mkdir /home/hived/block_log_5m; mv /home/hived/datadir/blockchain/block_log /home/hived/block_log_5m/block_log; fi

COPY --from=build \
  /home/haf_admin/build/hive/programs/hived/hived \
  /home/haf_admin/build/hive/programs/cli_wallet/cli_wallet \
  /home/haf_admin/build/hive/programs/util/compress_block_log \
  /home/haf_admin/build/hive/programs/blockchain_converter/blockchain_converter* \
  /home/hived/bin/

RUN mkdir -p /home/hived/shm_dir && mkdir -p /home/hived/datadir

USER haf_admin
WORKDIR /home/haf_admin

# TODO: if we remove those 2 commands we could save 300MB of image size, resulting in 70MB and +-4GB shared layers
COPY --from=build /home/haf_admin/build /home/haf_admin/build/
COPY --from=build /home/haf_admin/haf /home/haf_admin/haf/

ADD ./docker/docker_entrypoint.sh .
ADD --chown=postgres:postgres ./docker/postgresql.conf /etc/postgresql/12/main/postgresql.conf
ADD --chown=postgres:postgres ./docker/pg_hba.conf /etc/postgresql/12/main/pg_hba.conf.default

VOLUME [ "/home/hived/datadir", "/home/hived/shm_dir" ]

STOPSIGNAL SIGINT 

ADD --chown=hived:hived ./docker/$CONFIG_INI /home/hived/config.ini

ENTRYPOINT [ "/home/haf_admin/docker_entrypoint.sh" ]

CMD ["--replay-blockchain", "--stop-replay-at-block=5000000"]

EXPOSE 5432

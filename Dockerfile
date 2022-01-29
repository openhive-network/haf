# Base docker file having defined environment for build and run of HAF instance.
# docker build -t registry.gitlab.syncad.com/hive/haf/ci-base-image:ubuntu20.04-xxx -f Dockerfile .
# To be started from cloned haf source directory.
FROM phusion/baseimage:focal-1.0.0 AS ci-base-image

ENV LANG=en_US.UTF-8

USER root
WORKDIR /usr/local/src
ADD ./scripts /usr/local/src/scripts

RUN ./scripts/setup_ubuntu.sh --haf_admin_account="haf_admin" --hived_account="hived"

USER haf_admin

WORKDIR /home/haf_admin


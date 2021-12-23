# docker build -f Dockerfile -t haf .
FROM phusion/baseimage:focal-1.0.0

ENV LANG=en_US.UTF-8

RUN \
    apt-get update \
    && apt-get install -y \
    systemd \
    autoconf \
    postgresql \
    postgresql-contrib \
    build-essential \
    cmake \
    libboost-all-dev \
    postgresql-server-dev-12 \
    git \
    python3-pip \
    libssl-dev \
    libreadline-dev \
    libsnappy-dev \
    libpqxx-dev \
    clang \
    clang-tidy \
    ca-certificates \
    && \
    apt-get clean

RUN \
    python3 -mpip install \
    pexpect \
    psycopg2 \
    sqlalchemy \
    jinja2

ADD . /usr/local/src
WORKDIR /usr/local/src

USER postgres
RUN  /etc/init.d/postgresql start \
    && psql --command "CREATE USER root WITH SUPERUSER CREATEDB;"

USER root

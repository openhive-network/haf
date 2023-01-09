#! /bin/bash

set -euo pipefail

# Script purpose is an installation of all packages required to build and run HAF instance.
# After changing it, please also update and push to the registry a docker image defined in https://gitlab.syncad.com/hive/haf/-/blob/develop/Dockerfile

#Updated docker image must be also explicitly referenced in the https://gitlab.syncad.com/hive/haf/-/blob/develop/.gitlab-ci.yml#L7


print_help () {
    echo "Usage: $0 [OPTION[=VALUE]]..."
    echo
    echo "Allows to setup this machine for HAF installation"
    echo "OPTIONS:"
    echo "  --dev                     Allows to install all packages required to build and run haf project."
    echo "  --haf-admin-account=NAME  Allows to specify the account name to be used for HAF administration. (it is associated to the PostgreSQL role)"
    echo "  --hived-account=NAME      Allows to specify the account name to be used for hived process. (it is accociated to PostgreSQL role)."
    echo "  --help                    Display this help screen and exit"
    echo
}

haf_admin_unix_account="haf_admin"
hived_unix_account="hived"

assert_is_root() {
  if [ "$EUID" -ne 0 ]
    then echo "Please run as root"
    exit 1
  fi
}

install_all_dev_packages() {
  echo "Attempting to install all dev packages..."
  assert_is_root

  apt-get update
  DEBIAN_FRONTEND=noniteractive apt-get install -y \
          systemd \
          autoconf \
          wget \
          postgresql-12=12.12-0ubuntu0.20.04.1 \
          postgresql-contrib \
          build-essential \
          cmake \
          libboost-all-dev \
          git \
          python3-pip \
          python3-jinja2 \
          libssl-dev \
          libreadline-dev \
          libsnappy-dev \
          libpqxx-dev \
          clang \
          clang-tidy \
          tox \
          joe \
          sudo \
          ca-certificates \
          ninja-build

  python_version=$(python3 -c 'import sys; print("{}.{}".format(sys.version_info.major, sys.version_info.minor))')
  DEBIAN_FRONTEND=noniteractive apt-get install -y \
          python${python_version}-venv

  postgres_major_version=$(pg_config --version | sed 's/PostgreSQL \([0-9]*\)\..*/\1/g')
  DEBIAN_FRONTEND=noniteractive apt-get install -y \
          postgresql-server-dev-${postgres_major_version}
  apt-get clean
}

create_haf_admin_account() {
  echo "Attempting to create $haf_admin_unix_account account..."
  assert_is_root

  # Unfortunetely haf_admin must be able to su as root, because it must be able to write into /usr/share/postgresql/12/extension directory, being owned by root (it could be owned by postgres)
  if id "$haf_admin_unix_account" &>/dev/null; then
      echo "Account $haf_admin_unix_account already exists. Creation skipped."
  else
      useradd -ms /bin/bash "$haf_admin_unix_account" && echo "$haf_admin_unix_account ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
  fi
}

create_hived_account() {
  echo "Attempting to create $hived_unix_account account..."
  assert_is_root

  if id "$hived_unix_account" &>/dev/null; then
      echo "Account $hived_unix_account already exists. Creation skipped."
  else
      useradd -ms /bin/bash "$hived_unix_account"
  fi
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dev)
        install_all_dev_packages
        ;;
    --haf-admin-account=*)
        haf_admin_unix_account="${1#*=}"
        create_haf_admin_account
        ;;
    --hived-account=*)
        hived_unix_account="${1#*=}"
        create_hived_account
        ;;
    --help)
        print_help
        exit 0
        ;;
    -*)
        echo "ERROR: '$1' is not a valid option"
        echo
        print_help
        exit 1
        ;;
    *)
        echo "ERROR: '$1' is not a valid argument"
        echo
        print_help
        exit 2
        ;;
    esac
    shift
done

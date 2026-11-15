#! /bin/bash

SCRIPT_DIR=$(dirname "$(realpath "$0")")
SRC_DIR="$SCRIPT_DIR/.."

set -euo pipefail

POSTGRES_VERSION="${POSTGRES_VERSION:-17}"
# Oldest acceptable minor release of POSTGRES_VERSION (e.g. 18.7); the Dockerfile sets it.
POSTGRES_MINOR_VERSION="${POSTGRES_MINOR_VERSION:-}"

# This script installs all packages required to build and run a HAF instance.
# After changing it, please also update and push to the registry a docker image defined in https://gitlab.syncad.com/hive/haf/-/blob/develop/Dockerfile
# The updated docker image must also be explicitly referenced on line https://gitlab.syncad.com/hive/haf/-/blob/develop/.gitlab-ci.yml#L7

print_help () {
    echo "Usage: $0 [OPTION[=VALUE]]..."
    echo
    echo "Setup this machine for HAF installation."
    echo "OPTIONS:"
    echo "  --dev                     Install packages required to build and run a HAF server."
    echo "  --ai                      Install pgai"
    echo "  --user                    Install packages to a subdirectory of the user's home directory."
    echo "  --hived-account=NAME      Specify the unix account name to be used for hived (UID 1000, with sudo)."
    echo "  --check-postgres-version  Fail unless the installed PostgreSQL server is at least POSTGRES_MINOR_VERSION."
    echo "  --help                    Display this help screen and exit."
    echo
}

hived_unix_account="hived"

assert_is_root() {
  if [ "$EUID" -ne 0 ]
    then echo "Please run as root."
    exit 1
  fi
}

check_postgres_version() {
  if [ -z "${POSTGRES_MINOR_VERSION}" ]; then
    echo "ERROR: POSTGRES_MINOR_VERSION is not set; cannot check the installed PostgreSQL version." >&2
    exit 1
  fi

  local postgres_bin="/usr/lib/postgresql/${POSTGRES_VERSION}/bin/postgres"
  local installed
  # "postgres (PostgreSQL) 18.7 (Ubuntu 18.7-1.pgdg26.04+2)" -> "18.7"
  installed=$("$postgres_bin" --version | sed -nE 's/^postgres \(PostgreSQL\) ([0-9]+\.[0-9]+).*/\1/p')
  if [ -z "$installed" ]; then
    echo "ERROR: cannot determine the PostgreSQL version from '$("$postgres_bin" --version)'." >&2
    exit 1
  fi

  # pgdg serves only its newest minor, so this accepts a newer one rather than pinning an exact version.
  if dpkg --compare-versions "$installed" lt "$POSTGRES_MINOR_VERSION"; then
    echo "ERROR: installed PostgreSQL ${installed} is older than the required ${POSTGRES_MINOR_VERSION}." >&2
    exit 1
  fi
  echo "Installed PostgreSQL ${installed} (required: at least ${POSTGRES_MINOR_VERSION})."
}

install_ai_packages() {
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    git \
    python3 python3-venv python3-dev python3-pip \
    postgresql-plpython3-${POSTGRES_VERSION} \
    curl \
    python3-bs4 python3-lxml

  apt-get clean
  rm -rf /var/lib/apt/lists/*
  rm -rf /root/.cache ~/.cache /tmp/* /var/tmp/*
  find / -type d -name '__pycache__' -exec rm -rf {} +

  # typing_extensions first, as a pip-managed copy under /usr/local that
  # shadows Ubuntu's python3-typing-extensions (4.15.0, pulled in by apt
  # above). tokenizers -> huggingface_hub -> anyio 4.15.1+ needs >= 4.16.0,
  # and pip cannot replace the Debian package ("no RECORD file was found"),
  # which failed every fresh image build once the layer cache expired.
  pip3 install --break-system-packages --ignore-installed typing_extensions
  pip3 install --break-system-packages tokenizers base58

  mkdir -p /home/hived/tokenizer-files
  cat << EOF > /tmp/download-tokenizer-files.py
from huggingface_hub import snapshot_download

# e5-base (default model)
snapshot_download(
    repo_id="intfloat/multilingual-e5-base",
    local_dir="/home/hived/tokenizer-files/e5-base",
    allow_patterns=[
      "tokenizer.json",
      "tokenizer_config.json",
      "special_tokens_map.json",
      "sentencepiece.bpe.model",
    ]
)

# Jina v5 small
snapshot_download(
    repo_id="jinaai/jina-embeddings-v5-text-small",
    local_dir="/home/hived/tokenizer-files/jina-v5-small",
    allow_patterns=[
      "tokenizer.json",
    ]
)
EOF
  python3 /tmp/download-tokenizer-files.py
  rm /tmp/download-tokenizer-files.py
  chown -R hived.users /home/hived/tokenizer-files
}

install_all_dev_packages() {
  echo "Attempting to install all dev packages..."
  assert_is_root

  "$SRC_DIR/hive/scripts/setup_ubuntu.sh" --runtime --dev

  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
          systemd \
          libpq-dev \
          tox \
          joe \
          postgresql-common

  /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y

  if [ "${POSTGRES_VERSION}" -ge 18 ]; then
    sed -i -e 's/Suites: noble-pgdg/Suites: noble-pgdg-snapshot/' \
           -e "s/Components: main/Components: main ${POSTGRES_VERSION}/" \
           /etc/apt/sources.list.d/pgdg.sources
    echo 'Package: *' > /etc/apt/preferences.d/pgdg.pref
    echo 'Pin: origin apt.postgresql.org' >> /etc/apt/preferences.d/pgdg.pref
    echo 'Pin-Priority: 1001' >> /etc/apt/preferences.d/pgdg.pref
  fi

  apt-get update

  DEBIAN_FRONTEND=noninteractive apt-get install -y postgresql-${POSTGRES_VERSION} postgresql-server-dev-${POSTGRES_VERSION} \
  netcat-openbsd \
  git python3 python3-venv python3-dev python3-pip postgresql-plpython3-${POSTGRES_VERSION} curl # for hivesense

  apt-get clean
  rm -rf /var/lib/apt/lists/*

  if [ -n "${POSTGRES_MINOR_VERSION}" ]; then
    check_postgres_version
  fi

  pushd /tmp
  git clone https://github.com/citusdata/pg_cron.git
  cd pg_cron

  make && make install
  cd ..
  rm -r pg_cron
  popd

  sudo usermod -a -G users -c "PostgreSQL daemon account" postgres

  # Note: libpqxx is now pre-installed in ci-base-image (ubuntu24.04-py3.14-7+)
}

install_user_packages() {
  echo "Attempting to install user packages..."

  "$SRC_DIR/hive/scripts/setup_ubuntu.sh" --user
}

create_maintenance_account() {
  echo "Attempting to create haf_maintainer account..."
  useradd -r -s /usr/sbin/nologin -b /nonexistent -c "HAF maintenance service account" -U haf_maintainer
}

create_hived_account() {
  echo "Attempting to create $hived_unix_account account..."
  "$SRC_DIR/hive/scripts/setup_ubuntu.sh" --hived-account="$hived_unix_account"
  sudo -n chown -Rc "$hived_unix_account":users "/home/$hived_unix_account"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dev)
        install_all_dev_packages
        install_ai_packages
        create_maintenance_account
        ;;
    --ai)
        install_ai_packages
        ;;
    --user)
        install_user_packages
        ;;
    --haf-admin-account=*)
        echo "Warning: --haf-admin-account is deprecated and ignored. Use --hived-account instead."
        ;;
    --hived-account=*)
        hived_unix_account="${1#*=}"
        create_hived_account
        ;;
    --check-postgres-version)
        check_postgres_version
        ;;
    --help)
        print_help
        exit 0
        ;;
    -*)
        echo "ERROR: '$1' is not a valid option."
        echo
        print_help
        exit 1
        ;;
    *)
        echo "ERROR: '$1' is not a valid argument."
        echo
        print_help
        exit 2
        ;;
    esac
    shift
done

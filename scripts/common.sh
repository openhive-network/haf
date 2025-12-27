#! /bin/bash

set -euo pipefail 

exec > >(tee -i "${LOG_FILE}") 2>&1

log_exec_params() {
  echo
  echo -n "$0 parameters: "
  for arg in "$@"; do echo -n "$arg "; done
  echo
}

do_clone_commit() {
  local commit="$1"
  local src_dir=$2
  local repo_url=$3

  echo "Cloning commit: $commit from $repo_url into: $src_dir ..."
  mkdir -p "$src_dir"
  pushd "$src_dir"

  git init
  git remote add origin "$repo_url"
  git fetch --depth 1 origin "$commit"
  git checkout FETCH_HEAD

  # Check if hive submodule needs special handling (feature branch)
  if [[ -f .gitmodules ]] && grep -q "branch = feature/" .gitmodules; then
    HIVE_BRANCH=$(git config -f .gitmodules submodule.hive.branch 2>/dev/null || echo "")
    if [[ -n "$HIVE_BRANCH" ]]; then
      echo "Initializing hive submodule from feature branch: $HIVE_BRANCH"
      HIVE_COMMIT=$(git ls-tree HEAD hive | awk '{print $3}')
      HIVE_URL=$(git config -f .gitmodules submodule.hive.url)
      # Convert relative URL to absolute if needed
      if [[ "$HIVE_URL" == ../* ]]; then
        HIVE_URL="https://gitlab.syncad.com/hive/hive.git"
      fi
      # Clone the hive submodule, then fetch feature branch and checkout commit
      rm -rf hive
      git clone --no-checkout "$HIVE_URL" hive
      pushd hive
      git fetch origin "$HIVE_BRANCH" --depth=1
      git fetch --depth=1 origin "$HIVE_COMMIT" || true
      git checkout "$HIVE_COMMIT"
      popd
      # Now update remaining submodules recursively
      git submodule update --init --recursive
    else
      git submodule update --init --recursive
    fi
  else
    git submodule update --init --recursive
  fi

  popd
}

do_clone_branch() {
  local branch=$1
  local src_dir="$2"
  local repo_url="$3"
  echo "Cloning branch: $branch from $repo_url ..."
  git clone --recurse-submodules --shallow-submodules --single-branch --depth=1 --branch "$branch" -- "$repo_url" "$src_dir"
}


do_clone() {
  local branch=$1
  local src_dir="$2"
  local repo_url="$3"
  local commit="$4"

  if [[ "$commit" != "" ]]; then
    do_clone_commit "$commit" "$src_dir" "$repo_url"
  else
    do_clone_branch "$branch" "$src_dir" "$repo_url"
  fi
}


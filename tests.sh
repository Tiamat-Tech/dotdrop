#!/usr/bin/env bash
# author: deadc0de6 (https://github.com/deadc0de6)
# Copyright (c) 2017, deadc0de6

# stop on first error
set -eu -o errtrace -o pipefail

MULTI_PYTHON="" # set to test multi python envs
PYTHON_VERSIONS=("3.6" "3.7" "3.8" "3.9" "3.10" "3.11" "3.12" "3.13" "3.14")

test()
{
  echo "=> python version:"
  python3 --version

  # test syntax
  echo "checking syntax..."
  "${cur}"/scripts/check-syntax.sh

  # unittest
  echo "unittest..."
  "${cur}"/scripts/check-unittests.sh

  # tests-ng
  if [ -n "${in_cicd}" ]; then
    # in CI/CD
    export DOTDROP_WORKERS=1
    echo "tests-ng with ${DOTDROP_WORKERS} worker(s)..."
    "${cur}"/scripts/check-tests-ng.sh

    export DOTDROP_WORKERS=4
    echo "tests-ng with ${DOTDROP_WORKERS} worker(s)..."
    "${cur}"/scripts/check-tests-ng.sh
  else
    echo "tests-ng..."
    "${cur}"/scripts/check-tests-ng.sh
  fi
}

cur=$(cd "$(dirname "${0}")" && pwd)
in_cicd="${GITHUB_WORKFLOW:-}"

if [ -n "${in_cicd}" ]; then
  # patch TERM var in ci/cd
  if [ -z "${TERM}" ]; then
    export TERM="linux"
  fi
fi

# make sure both version.py and manpage dotdrop.1 are in sync
dotdrop_version=$(grep version dotdrop/version.py | sed 's/^.*= .\(.*\).$/\1/g')
man_version=$(grep '^\.TH' manpage/dotdrop.1  | sed 's/^.*"dotdrop-\(.*\)\" "Save your.*$/\1/g')
if [ "${dotdrop_version}" != "${man_version}" ]; then
  echo "ERROR version.py (${dotdrop_version}) and manpage (${man_version}) differ!"
  exit 1
fi
echo "current dotdrop version ${dotdrop_version}"

if [ -n "${in_cicd}" ]; then
  test
else
  if [ -n "${MULTI_PYTHON}" ]; then
    if ! hash pyenv &>/dev/null; then
      echo "install pyenv"
      exit 1
    fi

    eval "$(pyenv init -)"
    for PY in "${PYTHON_VERSIONS[@]}"; do
        echo "============== python ${PY} =============="
        pyenv install -s "${PY}"
        pyenv shell "${PY}"
        python -m venv ".venv"
        source ".venv/bin/activate"
        pip install pip --upgrade
        pip install -r requirements.txt
        pip install -r tests-requirements.txt
        test
        deactivate
    done
  else
    python3 -m venv ".venv"
    source ".venv/bin/activate"
    pip install pip --upgrade
    pip install -r requirements.txt
    pip install -r tests-requirements.txt
    test
    deactivate
  fi
fi


# merge coverage
coverage combine coverages/*
coverage xml

# test doc
if [ -z "${in_cicd}" ]; then
  # not in CI/CD
  echo "checking documentation..."
  "${cur}"/scripts/check-doc.sh
fi

## done
echo "All tests finished successfully"

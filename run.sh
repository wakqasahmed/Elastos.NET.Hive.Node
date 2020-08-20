#!/usr/bin/env bash

function start_db () {
    docker container stop hive-mongo || true && docker container rm -f hive-mongo || true
    docker run -d --name hive-mongo                     \
        -v ${PWD}/.mongodb-data:/data/db                \
        -p 27020:27017                                  \
        mongo
}

function setup_venv () {
    case `uname` in
    Linux )
        virtualenv -p `which python3.6` .venv
        source .venv/bin/activate
        pip install --upgrade pip
        pip install -r requirements.txt
        ;;
    Darwin )
        virtualenv -p `which python3.7` .venv
        source .venv/bin/activate
        pip install --upgrade pip
        pip install --global-option=build_ext --global-option="-I/usr/local/include" --global-option="-L/usr/local/lib" -r requirements.txt
        ;;
    *)
    exit 1
    ;;
    esac
}

function start_docker () {
    start_db

    echo "Running using docker..."
    docker container stop hive-node || true && docker container rm -f hive-node || true
    docker build -t elastos/hive-node .
    docker run --name hive-node                     \
      -v ${PWD}/data:/src/data               \
      -v ${PWD}/.env:/src/.env                \
      -p 5000:5000                                  \
      elastos/hive-node
}

function start_direct () {
    start_db

    echo "Running directly on the machine..."
    ps -ef | grep gunicorn | awk '{print $2}' | xargs kill -9

    setup_venv

    LD_LIBRARY_PATH="$PWD/hive/util/did/" gunicorn -b 0.0.0.0:5000 --reload wsgi:application
}

function test () {
    start_db

    setup_venv

    # Run tests
    pytest tests/hive_auth_test.py
    pytest tests/hive_sync_test.py
    pytest tests/hive_mongo_test.py
    pytest tests/hive_file_test.py
}

case "$1" in
    direct)
        start_direct
        ;;
    docker)
        start_docker
        ;;
    test)
        test
        ;;
    *)
    echo "Usage: run.sh {docker|direct|test}"
    exit 1
esac
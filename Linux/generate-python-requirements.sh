#!/bin/env sh

set -e

if ! command python3 -m pipreqs -h &>/dev/null; then
    echo "Please install pipreqs first."
    [[ -z "$VIRTUAL_ENV" ]] && \
        echo "And initialize a virtual environment."
    echo "python3 -m pip install pipreq"
fi

pushd "$(git rev-parse --show-toplevel)" || echo "Cannot find project root"
pipreqs --savepath=requirements.in && \
    pip-compile --rebuild && \
    rm ./requirements.in
popd

echo 'Done! (´• ω •`)'


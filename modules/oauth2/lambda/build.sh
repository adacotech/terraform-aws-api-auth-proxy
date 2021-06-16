#!/bin/bash

# usage: build.sh tag_name context_dir


docker build --tag $1:latest $2 -f $3/Dockerfile
docker run --rm --volume $3:/build -w /build $1:latest /bin/bash -c "rsync -ar --exclude .gitignore --delete /root/output/ /build/dst/$1 && chmod a+r -R /build/dst/$1"


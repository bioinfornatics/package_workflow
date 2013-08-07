#!/usr/bin/env bash
# earth-and-moon-backgrounds
. "$(dirname $0)"/common.sh
declare originalDir sourceFile

init 'earth-and-moon-backgrounds'

for sourceFile in "${sourcesFiles}"; do
    if [[ ! -f "${sourceFile}" ]] ; then
        curl -s -o "${sourceFile}" http://bioinfornatics.fedorapeople.org/$(basename "${sourceFile}")
    fi
done

build

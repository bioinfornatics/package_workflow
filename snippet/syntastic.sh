#!/usr/bin/env bash
# syntastic
declare syntastic_revision alphatag

. "$(dirname $0)"/common.sh

init 'syntastic'

gitGetRepo 'git://github.com/scrooloose/syntastic.git'
gitExtractSnapDate
gitExtractRev
syntastic_revision="${revision}"
alphatag="${snapdate}"git"${syntastic_revision}"

gitArchive "${package_name}-${alphatag}" "${package_name}-${alphatag}" "${SOURCES}"

udpateSpec  "Update to rev ${syntastic_revision}"                                           \
            '%global[[:blank:]]*snapdate[[:blank:]]*(.*)'           "${snapdate}"           \
            '%global[[:blank:]]*revision[[:blank:]]*(.*)'  "${syntastic_revision}"
localBuild

remoteBuild "Updating to rev ${syntastic_revision}"

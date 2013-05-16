#!/usr/bin/env bash
# dsqlite

declare alphatag dsqlite_revision originalDir

. "$(dirname $0)"/common.sh

init 'dsqlite'

gitGetRepo 'git://github.com/bioinfornatics/DSQLite.git'
gitExtractSnapDate
gitExtractRev
dsqlite_revision="${revision}"
alphatag="${snapdate}"git"${dsqlite_revision}"

gitArchive "${package_name}-${alphatag}" "${package_name}-${alphatag}" "${SOURCES}"

udpateSpec  "Update to rev ${dsqlite_revision}"                                                 \
            '%global[[:blank:]]*snapdate[[:blank:]]*(.*)'               "${snapdate}"           \
            '%global[[:blank:]]*dsqlite_revision[[:blank:]]*(.*)'       "${dsqlite_revision}"
localBuild

remoteBuild "Updating to rev ${dsqlite_revision}"

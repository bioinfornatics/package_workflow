#!/usr/bin/env bash
# dustmite

declare alphatag dustmite_revision

. "$(dirname $0)"/common.sh

init 'dustmite'

gitGetRepo 'git://github.com/CyberShadow/DustMite.git'
gitExtractSnapDate
gitExtractRev
dustmite_revision="${revision}"
alphatag="${snapdate}"git"${dustmite_revision}"

gitArchive "${package_name}-${alphatag}" "${package_name}-${alphatag}" "${SOURCES}"

udpateSpec  "Update to rev ${dustmite_revision}"                                                \
            '%global[[:blank:]]*snapdate[[:blank:]]*(.*)'                "${snapdate}"          \
            '%global[[:blank:]]*dustmite_revision[[:blank:]]*(.*)'       "${dustmite_revision}"

localBuild

remoteBuild "Updating to rev ${dustmite_revision}"

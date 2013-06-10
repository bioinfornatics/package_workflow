#!/usr/bin/env bash
# tango

declare alphatag tango_revision

. "$(dirname $0)"/common.sh

init 'tango'

gitGetRepo 'git://github.com/SiegeLord/Tango-D2.git'
gitExtractSnapDate
gitExtractRev
tango_revision="${revision}"
alphatag="${snapdate}"git"${tango_revision}"

gitArchive "${package_name}-${alphatag}" "${package_name}-${alphatag}" "${SOURCES}"

udpateSpec  "Update to rev ${tango_revision}"                                                 \
            '%global[[:blank:]]*snapdate[[:blank:]]*(.*)'             "${snapdate}"           \
            '%global[[:blank:]]*tango_revision[[:blank:]]*(.*)'       "${tango_revision}"

localBuild

remoteBuild "Updating to rev ${tango_revision}"

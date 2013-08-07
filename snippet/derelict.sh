#!/usr/bin/env bash
# derelict
declare derelict_revision alphatag

. "$(dirname $0)"/common.sh

init 'derelict'

gitGetRepo 'git://github.com/aldacron/Derelict3.git'
gitExtractSnapDate
gitExtractRev
derelict_revision="${revision}"
alphatag="${snapdate}"git"${derelict_revision}"


gitArchive "${package_name}-${alphatag}" "${package_name}-${alphatag}" "${SOURCES}"


udpateSpec  "Update to rev ${derelict_revision}"                                            \
            '%global[[:blank:]]*snapdate[[:blank:]]*(.*)'           "${snapdate}"           \
            '%global[[:blank:]]*derelict_revision[[:blank:]]*(.*)'  "${derelict_revision}"

build "Updating to rev ${derelict_revision}"

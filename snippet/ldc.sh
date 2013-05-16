#!/usr/bin/env bash
# ldc

declare ldc_rev phobos_rev  druntime_rev alphatag phobostag druntimetag

. "$(dirname $0)"/common.sh

init 'ldc'

[[ -f "${SOURCES}"'/macros.ldc' ]] || curl -s -o "${SOURCES}"'/macros.ldc' http://bioinfornatics.fedorapeople.org/macros.ldc

gitGetRepo 'git://github.com/ldc-developers/ldc.git'
git submodule update -i > /dev/null
gitExtractSnapDate

gitExtractRev
ldc_rev="${revision}"
alphatag="${snapdate}"git"${ldc_rev}"
gitArchive "${package_name}-${alphatag}" "${package_name}-${alphatag}" "${SOURCES}"


cd runtime/druntime
gitExtractRev
druntime_rev="${revision}"
druntimetag="${snapdate}"git"${druntime_rev}"
gitArchive 'runtime/druntime' "${package_name}-druntime-${druntimetag}" "${SOURCES}"

cd ../phobos
gitExtractRev
phobos_rev="${revision}"
phobostag="${snapdate}"git"${phobos_rev}"
gitArchive 'runtime/phobos' "${package_name}-phobos-${phobostag}" "${SOURCES}"

cd "${originalDir}"

udpadeSpec  "Update to rev ${ldc_rev}"                                              \
            '%global[[:blank:]]*snapdate[[:blank:]]*(.*)'       "${snapdate}"       \
            '%global[[:blank:]]*ldc_rev[[:blank:]]*(.*)'        "${ldc_rev}"        \
            '%global[[:blank:]]*phobos_rev[[:blank:]]*(.*)'     "${phobos_rev}"     \
            '%global[[:blank:]]*druntime_rev[[:blank:]]*(.*)'   "${druntime_rev}"

localBuild

remoteBuild "Updating to rev ${ldc_rev}"

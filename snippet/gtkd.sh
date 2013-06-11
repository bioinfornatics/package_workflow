#!/usr/bin/env bash
# gtkd
. "$(dirname $0)"/common.sh

declare gtkd_revision alphatag

init 'gtkd'
gitGetRepo 'git://github.com/gtkd-developers/GtkD.git'
gitExtractSnapDate
gitExtractRev
gtkd_revision="${revision}"
alphatag="${snapdate}"git"${gtkd_revision}"

gitArchive "${package_name}-${alphatag}" "${package_name}-${alphatag}" "${SOURCES}"

udpateSpec  "Update to rev ${gtkd_revision}"                                        \
            '%global[[:blank:]]*snapdate[[:blank:]]*(.*)'       "${snapdate}"       \
            '%global[[:blank:]]*gtkd_revision[[:blank:]]*(.*)'  "${gtkd_revision}"
localBuild

remoteBuild "Updating to rev ${gtkd_revision}"

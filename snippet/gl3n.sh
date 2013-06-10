#!/usr/bin/env bash
# gl3n

declare alphatag gl3n_revision

. "$(dirname $0)"/common.sh

init 'gl3n'

gitGetRepo 'https://github.com/Dav1dde/gl3n'
gitExtractSnapDate
gitExtractRev
gl3n_revision="${revision}"
alphatag="${snapdate}"git"${gl3n_revision}"

gitArchive "${package_name}-${alphatag}" "${package_name}-${alphatag}" "${SOURCES}"

udpateSpec  "Update to rev ${gl3n_revision}"                                                 \
            '%global[[:blank:]]*snapdate[[:blank:]]*(.*)'             "${snapdate}"           \
            '%global[[:blank:]]*gl3n_revision[[:blank:]]*(.*)'       "${gl3n_revision}"

localBuild

remoteBuild "Updating to rev ${gl3n_revision}"

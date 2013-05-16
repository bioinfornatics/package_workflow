#!/usr/bin/env bash
# gdesklets-citation
. "$(dirname $0)"/common.sh
declare alphatag gdesklets_citation_revision originalDir

init 'gdesklets-citation'

gitGetRepo 'https://github.com/bioinfornatics/gdesklets-citation.git'
gitExtractSnapDate
gitExtractRev
gdesklets_citation_revision="${revision}"
alphatag="${snapdate}"git"${gdesklets_citation_revision}"

gitArchive "${package_name}-${alphatag}" "${package_name}-${alphatag}" "${SOURCES}"

udpateSpec  "Update to rev ${gdesklets_citation_revision}"                                  \
            '%global[[:blank:]]*snapdate[[:blank:]]*(.*)'  "${snapdate}"                    \
            '%global[[:blank:]]*rev[[:blank:]]*(.*)'       "${gdesklets_citation_revision}"
localBuild

remoteBuild "Updating to rev ${gdesklets_citation_revision}"

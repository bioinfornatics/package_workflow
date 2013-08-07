#!/usr/bin/env bash
# glfw

. "$(dirname $0)"/common.sh

declare alphatag glfw_revision

init 'glfw'

gitGetRepo 'git://github.com/glfw/glfw.git'
gitExtractSnapDate
gitExtractRev
glfw_revision="${revision}"
alphatag="${snapdate}"git"${glfw_revision}"

gitArchive "${package_name}-${alphatag}" "${package_name}-${alphatag}" "${SOURCES}"

udpateSpec  "Update to rev ${glfw_revision}"                                            \
            '%global[[:blank:]]*snapdate[[:blank:]]*(.*)'           "${snapdate}"       \
            '%global[[:blank:]]*glfw_revision[[:blank:]]*(.*)'      "${glfw_revision}"

build "Updating to rev ${glfw_revision}"

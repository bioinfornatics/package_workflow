#!/usr/bin/env bash
# gdesklet-SlideShow

. "$(dirname $0)"/common.sh

declare app0 app1 sourceFile0 sourceFile1 urlSource0 urlSource1

init 'gdesklet-SlideShow'
app0='SlideShow-0.9.tar.gz'
app1='ImageSlideShow-0.8.tar.gz'
sourceFile0="${SOURCES}"/"${app0}"
sourceFile1="${SOURCES}"/"${app1}"
urlSource0='http://www.gdesklets.de/files/desklets/SlideShow/'"${app0}"
urlSource1='http://www.gdesklets.de/files/controls/ImageSlideShow/'"${app1}"

[[ -f "${sourceFile0}" ]] || curl -o "${sourceFile0}" "${urlSource0}" > /dev/null


[[ -f "${sourceFile1}" ]] || curl -o "${sourceFile1}" "${urlSource1}" > /dev/null

localBuild

remoteBuild

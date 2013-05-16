
declare -r  RPMBUILD="${HOME}"/rpmbuild
declare -r  SOURCES="${RPMBUILD}"/SOURCES
declare -r  SPECS="${RPMBUILD}"/SPECS
declare -r  SRPMS="${RPMBUILD}"/SRPMS
declare -r  RPMS="${RPMBUILD}"/RPMS
declare -r  LOGDIR="${RPMBUILD}"/LOG
declare     MAIL
declare     NAME
declare     USERSTRING="${NAME} <${MAIL}>"
declare     LOGIN

declare -r  RESET="$(tput sgr0)"
declare -r  BOLD="$(tput bold)"
declare -r  BLACKF="$(tput setaf 0)"
declare -r  BLACKB="$(tput setab 0)"
declare -r  REDF="$(tput setaf 1)"
declare -r  REDB="$(tput setab 1)"
declare -r  GREENF="$(tput setaf 2)"
declare -r  GREENB="$(tput setab 2)"
declare -r  YELLOWF="$(tput setaf 3)"
declare -r  YELLOWB="$(tput setab 3)"
declare -r  BLUEF="$(tput setaf 4)"
declare -r  BLUEB="$(tput setab 4)"
declare -r  MAGENTAF="$(tput setaf 5)"
declare -r  MAGENTAB="$(tput setab 5)"
declare -r  CYANF="$(tput setaf 6)"
declare -r  CYANB="$(tput setab 6)"
declare -r  WHITEF="$(tput setaf 7)"
declare -r  WHITEB="$(tput setab 7)"


declare -x needToBump=false
declare -x force=false
declare -x suourceUpdated=false
declare -x isInitialized=false
declare -x verbose=false
declare -x branch
declare -x snapdate
declare -x revision
declare -x release
declare -x package_name
declare -x specFile
declare -x tmpSpecFile
declare -x logOut
declare -x logErr
declare -x originalDir
declare -x -a rpmsList=()
declare -x -a sourcesFiles=()

die () {
    local parent_lineno message code
      parent_lineno="$1"
      message="$2"
      [[ -n $3 ]] && code="$3" || code=1
      if [[ -n "$message" ]] ; then
        echo "Error on or near line ${parent_lineno}: ${message}; exiting with status ${code}" >&2
      else
        echo "Error on or near line ${parent_lineno}; exiting with status ${code}" >&2
      fi
      [[ -z  "${originalDir}" ]] && originalDir=$( readlink -f . )
      cd "${originalDir}"
      end "${code}"
}

init () {
    [[ $# -eq 1 ]]      || die ${LINENO} 'init expected a one parameter to set package_name. Not '"$#" 1
    [[ -n "$1" ]]       || die ${LINENO} 'Package name should to be not empty'
    [[ -n "{$branch}" ]]|| die ${LINENO} 'Branch name should to be not empty'
    package_name="$1"
    trap 'die ${LINENO}'  1 15 ERR
    trap 'end' EXIT
    specFile="${SPECS}"/"${package_name}"/"${package_name}"'.spec'
    tmpSpecFile="$(mktemp)"
    logOut="${LOGDIR}"'/'"${package_name}"'.out'
    logErr="${LOGDIR}"'/'"${package_name}"'.err'
    branchList=( $@ )
    originalDir=$( readlink -f . )
    
    cp "${specFile}" "${tmpSpecFile}"
    
    [[ -d "${LOGDIR}" ]]    || mkdir "${LOGDIR}"
    [[ -f "${specFile}" ]]  || die ${LINENO} "spec file: ${specFile} do not exist" 1
    [[ -f "${logOut}" ]]    && rm "${logOut}"
    [[ -f "${logErr}" ]]    && rm "${logErr}"
    isInitialized=true
    
    exec 3>&1  1>>"${logOut}" # Merqe fd 1 with fd 3 and Redirect to logOut file
    exec 4>&2  2>>"${logErr}" # Merqe fd 2 with fd 4 and Redirect to logErr file
    
    if [[ ! -f "${specFile}" ]]; then
        ( cd "${SPECS}" && fedpkg clone "${package_name}" )
    fi

    
    pushd "${SPECS}"/"${package_name}"/  1> /dev/null
        fedpkg switch-branch ${branch} 1> /dev/null
        fedpkg pull 1> /dev/null
    popd  1> /dev/null
    
    [[ $verbose == true ]] && echo 'Starting to process package '"${package_name}"
    getSourcesFiles
}

end (){
    local code
    [[ -n $1 ]] && code="$1" || code=0
    trap - EXIT
    trap - ERR
    exec 1>&3 3>&- # Restore stdout Close file descriptor #3
    exec 2>&4 4>&- # Restore stderr Close file descriptor #4
    cd "${originalDir}"
    exit "${code}"
}

configReader() {
    local section line configFile
    local -i lineNumber=1
    
    [[ $# -eq 1 ]] || die ${LINENO} "configReader expected a config file" 1
    configFile="$1"
    
    while read line; do 
        if [[ "${line}" == '[GLOBAL]' ]]; then
            section='[GLOBAL]'
        elif [[ "${line}" == '[BRANCH]' ]]; then
            section='[BRANCH]'
        elif [[ "${section}" == '[GLOBAL]' ]]; then
            if [[ "${line}" =~ ^([[:alnum:]_]+)[[:blank:]]*=[[:blank:]]*(.+)$ ]]; then
                case "${BASH_REMATCH[1]}" in
                    name)          NAME="${BASH_REMATCH[2]}";;
                    login)         LOGIN="${BASH_REMATCH[2]}";;
                    mail)          MAIL="${BASH_REMATCH[2]}";;
                    branchList)    branchList="${BASH_REMATCH[2]}";;
                    *) echo ${lineNumber} 'Unknow key '${BASH_REMATCH[1]};;
                esac
            else
                echo 'Warning: Unknow line format at '${lineNumber}
            fi
        elif [[ "${section}" == '[BRANCH]' ]]; then
            if [[ "${line}" =~ ^([[:alnum:]_]+)[[:blank:]]*=[[:blank:]]*(.+)$ ]]; then
                if [[ ${packageBranch["${BASH_REMATCH[1]}"]} ]]; then
                    packageBranch["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
                else
                    packageBranch["${BASH_REMATCH[1]}"]=",${BASH_REMATCH[2]}"
                fi
            else
                echo 'Warning: Unknow line format at '${lineNumber}
            fi
        fi
        ((lineNumber++))
    done < "${configFile}"
}

bumpSpec () {
    local comment
    [[ $# -eq 1 ]]                  || die ${LINENO} "bumpSpec expected a comment" 1
    [[ $isInitialized == true ]]    || die ${LINENO} "Error: you need to run init fuction at beginning" 1
    comment="$1"
    rpmdev-bumpspec -u "$USERSTRING" --comment="${comment}" "${tmpSpecFile}"
}

localBuild () {
    [[ $# -eq 0 ]]                  || die ${LINENO} "buildRPM expected 0 or 1 parameters not $#" 1
    [[ $isInitialized == true ]]    || die ${LINENO} "Error: you need to run init fuction at beginning" 1
    [[ $verbose == true ]]          && echo 'Building '"${package_name}"' rpms'
    
    if [[ $needToBump == false  && $force == true ]]; then
        bumpSpec "Rebuild"
    fi
    if [[ $needToBump == true  || $force == true ]]; then
        echo '==== Building '"${package_name}"' rpms ====' >&2
        rpmbuild -ba "${tmpSpecFile}"
        echo '==== End to build '"${package_name}"' rpms ====' >&2
    fi
}

getRPMS () {
    local line
    [[ $isInitialized == true ]]    || die ${LINENO} "Error: you need to run init fuction at beginning" 1
    if [[ -f "${logOut}" ]]; then
        for line in $(grep -e "${RPMBUILD}/.*\.rpm" "${logOut}"); do
            if [[ "${line}" =~ ^"${RPMBUILD}" ]]; then
                rpmsList+=("${line}")
            fi
        done
    fi
}

getSpecRelease () {
    local isSearching eof
    local -r pattern='^Release:[[:blank:]]+([[:digit:]]+)'
    [[ $isInitialized == true ]]    || die ${LINENO} "Error: you need to run init fuction at beginning" 1
    isSearching=true
    
    while isSearching; do
        eof=$(read line)
        
        if [[ "$eof" -ne 0 ]]; then
            isSearching=false
        elif [[ "${line}" =~ $pattern ]]; then
            isSearching=false
            release="${BASH_REMATCH[1]}"
        fi
    done  < "${tmpSpecFile}"
}

udpateSpec () {
    local comment parameters index match line pattern value tmpfile
    [[ $# -ge 1 ]]                                  || die ${LINENO} "udpadeSpec expected at least 1 parameters not $#" 1
    [[ $isInitialized == true ]]                    || die ${LINENO} "Error: you need to run init fuction at beginning" 1
    [[ -n "$1" ]]            && comment="$1"        || die ${LINENO} 'udpadeSpec expected a comment as second parameter' 1
    shift; shift
    [[ $verbose == true ]] && echo "Updating spec file: ${specFile}"
    
    if [[ -n "$@" ]]; then
        [[ $(( $# % 2 )) ]]  && parameters=( "$@" ) || die ${LINENO} 'udpadeSpec expected a paired numbers of parameters' 1
        
        tmpfile="$(mktemp)"
        
        while read -r line; do
            for ((index=0;  $index < ${#parameters[@]}; index+=2 )); do 
                pattern=${parameters[$index]}
                value=${parameters[$(( $index + 1 ))]}
                
                if [[ ${line} =~ ${pattern} && "${BASH_REMATCH[1]}" != "${value}" ]]; then
                    needToBump=true
                    line=${line/${BASH_REMATCH[1]}/${value}}
                fi
            done
            echo "${line}" >> "${tmpfile}"
        done < "${specFile}"
        if ${needToBump} ; then
            mv "${tmpfile}" "${tmpSpecFile}"
        fi
    else
        needToBump=true
    fi
   
    if ${needToBump} ; then
        bumpSpec "${comment}"
    fi
}

getSourcesFiles () {
    local line sourceFile url key hashValue varValue varName
    local -A variables
    while read line; do
        if [[ "${line}" =~ ^%global[[:blank:]]+([[:alnum:]_]+)[[:blank:]]+([[:alnum:][:punct:]]+) ]]; then
            varName='%{'"${BASH_REMATCH[1]}"'}'
            varValue="${BASH_REMATCH[2]}"
            if [[ "${varValue}" =~ [[:punct:]] ]]; then
                for key in "${!variables[@]}"; do
                        hashValue=${variables["${key}"]}
                    if [[ "${varValue}" =~ "${key}" ]]; then
                        varValue=${varValue//"${key}"/${hashValue}}
                    fi
                done
            fi
            variables["${varName}"]="${varValue}"
        elif [[ "${line}" =~ ^Name:[[:blank:]]+([[:alnum:][:punct:]]+) ]]; then
            variables['%{name'}]="${BASH_REMATCH[1]}"
        elif [[ "${line}" =~ ^Version:[[:blank:]]+([[:digit:]\.]+) ]]; then
            variables['%{version'}]="${BASH_REMATCH[1]}"
        elif [[ "${line}" =~ ^Patch|Source[[:digit:]]+:[[:blank:]]+([[:alnum:][:punct:]]+) ]]; then
            url="${BASH_REMATCH[1]}"
            if [[ "${url}" =~ ^http|ftp ]]; then
                sourceFile="${url##*/}"
            else
                sourceFile="${url}"
            fi
            for key in "${!variables[@]}"; do
                sourceFile=${sourceFile//"${key}"/${variables["${key}"]}}
            done
            sourcesFiles+=( "${SOURCES}"/"${sourceFile}" )  
        fi
    done < "${tmpSpecFile}"
    [[ ${#sourcesFiles} -ne 0 ]] || die ${LINENO} 'sources files List is epmty' 1
}

remoteBuild () {
    local comment untracked item
    [[ "$#" -eq 0 || "$#" -eq 1 ]]  || die ${LINENO} "updatePackage expected 0 or 1 parameters not $#" 1
    if [[ -n "$1" ]]; then
        comment="$1"
    else
        comment="Rebuild"
    fi
    if ${needToBump} ; then
        pushd "${SPECS}"/"${package_name}"/  1> /dev/null
        [[ $verbose == true ]] && echo 'Updating package '${package_name}'from branch '${branch}
        cp "${tmpSpecFile}" "${specFile}"
        untracked=( $(git ls-files -o) )
        for item in "${untracked[@]}"; do
            if [[ $(basename "${specFile}") == "${item}" ]]; then
                git add "${item}"
            fi
        done
        fedpkg new-sources ${sourcesFiles[@]}
        fedpkg commit -m "${comment}" -p
        fedpkg build
        #bodhi -u $LOGIN -c "${comment}" -N "${comment}" --type='enhancement' ${package_name}
        popd  1> /dev/null
    else
        echo "${package_name}"' already up to date. Nothing to do.'
    fi
}

gitGetRepo () {
    local repo
    [[ "$#" -eq 1 ]]                || die ${LINENO} "gitGetRepo expected 1 parameters not $#" 1
    [[ -n "$1" ]]   && repo="$1"    || die ${LINENO} 'gitGetRepo expected a git url repository' 1
    [[ $isInitialized == true ]]    || die ${LINENO} "Error: you need to run init fuction at beginning" 1
    if [[ ! -d "${SOURCES}"/"${package_name}" ]]; then
        git clone "${repo}" "${SOURCES}"/"${package_name}" 1> /dev/null
        cd "${SOURCES}"/"${package_name}"
    else
        cd "${SOURCES}"/"${package_name}"
        git pull 1> /dev/null
    fi
}

gitExtractSnapDate () {
    local date_string
    [[ $# -eq 0 ]]  || die ${LINENO} "gitExtractSnapDate expected 0 parameters not $#" 1
    [[ -e '.git' ]] || die ${LINENO} "Error: is not a git repository" 1
    date_string=$(git log -1 --format="%ci")
    date_string="${date_string%% *}"
    snapdate="${date_string//-/}"
}

gitExtractRev () {
    [[ $# -eq 0 ]]          || die ${LINENO} "gitExtractRev expected 0 parameters not $#" 1
    [[ -e '.git' ]]         || die ${LINENO} "Error: is not a git repository" 1
    [[ $verbose == true ]]  && echo "Extracting $(basename  $(pwd)) archive"
    revision="$(git rev-parse --short HEAD)"
}

gitArchive () {
    local package alphatag outputDir archive
    [[ $# -eq 3 ]]  || die ${LINENO} "gitArchive expected 3 parameters not $#" 1
    [[ -e '.git' ]] || die ${LINENO} "Error: is not a git repository" 1
    prefix="$1"
    package="$2"
    outputDir="$3"
    archive=$( readlink -m "${outputDir}"/"${package}".tar.xz )
    [[ -f "${archive}" ]] || $(git archive --prefix="${prefix}"/ HEAD --format=tar | xz > "${archive}" )
}

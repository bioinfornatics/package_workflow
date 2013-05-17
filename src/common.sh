

declare -x needToBump=false
declare -x suourceUpdated=false
declare -x isInitialized=false
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

# die
# This function is used to raise an error
# Paramecters:
# - line number
# - message
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

# init
# This function is used to initialized the workfow.
# Evry script need to start by this function
# Set log file for the given package
# Parameter:
# - package name
init () {
    [[ $# -eq 1 ]]          || die ${LINENO} 'init expected a one parameter to set package_name. Not '$# 1
    [[ -n "$1" ]]           || die ${LINENO} 'Package name should to be not empty' 1
    [[ -n "${branch}" ]]    || die ${LINENO} 'Branch name should to be not empty' 1
    [[ -n "${name}" ]]      || die ${LINENO} 'A real name to put into changelog is required' 1
    [[ -n "${mail}" ]]      || die ${LINENO} 'A mail to put into changelog is required' 1
    package_name="$1"
    trap 'die ${LINENO}'  1 15 ERR
    trap 'end' EXIT
    userstring="${name} <${mail}>"
    specFile="${SPECS}"/"${package_name}"/"${package_name}"'.spec'
    tmpSpecFile="$(mktemp)"
    logOut="${LOGDIR}"'/'"${package_name}_${branch}"'.out'
    logErr="${LOGDIR}"'/'"${package_name}_${branch}"'.err'
    branchList=( $@ )
    originalDir=$( readlink -f . )
    
    cp "${specFile}" "${tmpSpecFile}"
    
    [[ -d "${LOGDIR}" ]]    || mkdir "${LOGDIR}"
    [[ -f "${specFile}" ]]  || die ${LINENO} 'spec file: '${specFile}' do not exist' 1
    [[ -f "${logOut}" ]]    && rm "${logOut}"
    [[ -f "${logErr}" ]]    && rm "${logErr}"
    isInitialized=true
    [[ -e /proc/$$/fd/3 ]] && die ${LINENO} 'File descriptor 3 already used' 1
    [[ -e /proc/$$/fd/4 ]] && die ${LINENO} 'File descriptor 4 already used' 1
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

# end
# This function is used to correctly quit the script
# You do not have need to call it as this function is called automatically when scrit exiting.
# Parameter:
# - exit code default 0
end (){
    local code
    [[ -n $1 ]] && code="$1" || code=0
    trap - EXIT
    trap - ERR
    [[ -e /proc/$$/fd/3 ]] && exec 1>&3 3>&- # Restore stdout Close file descriptor #3
    [[ -e /proc/$$/fd/4 ]] && exec 2>&4 4>&- # Restore stderr Close file descriptor #4
    cd "${originalDir}"
    exit "${code}"
}

# bumpSpec
# This function is used to increase the release number
# You do not have need to call it as this function is called from localBuild and udpateSpec.
# Parameter:
# - comment to write into the spec file
bumpSpec () {
    local comment
    [[ $# -eq 1 ]]                  || die ${LINENO} "bumpSpec expected a comment" 1
    [[ $isInitialized == true ]]    || die ${LINENO} "Error: you need to run init fuction at beginning" 1
    comment="$1"
    rpmdev-bumpspec -u "$userstring" --comment="${comment}" "${tmpSpecFile}"
}

# localBuild
# This function is used to do a local build
# The build is done if package get an update or if variable force is true
localBuild () {
    [[ $# -eq 0 ]]                  || die ${LINENO} "buildRPM expected 0 or 1 parameters not $#" 1
    [[ $isInitialized == true ]]    || die ${LINENO} "Error: you need to run init fuction at beginning" 1
    [[ $verbose == true ]]          && echo 'Building '"${package_name}"' rpms'
    
    if [[ $needToBump == false  && $force == true ]]; then
        bumpSpec "Rebuild"
   elif [[ $needToBump == true  || $force == true ]]; then
        echo '==== Building '"${package_name}"' rpms ====' >&2
        rpmbuild -ba "${tmpSpecFile}"
        echo '==== End to build '"${package_name}"' rpms ====' >&2
    fi
}

# getRPMS
# This function is not used.
# This function allow to get list of generated rpm file by reading log file
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

# getSpecRelease
# This function is not used
# This function allow to get the current release number from the spec file
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

# udpateSpec
# This function is used to update spec file.
# Parameter:
# - comment to append into the changelog section
# - pairs of rules/new value to update into the spec file
#   The rule is a regexp with a group to catch.
#   If the regexp is true, it will replace the group caught by the given value.
#   If any rules is given that will force a build
udpateSpec () {
    local comment parameters index match line pattern value tmpfile
    [[ $# -ge 1 ]]                                  || die ${LINENO} 'udpadeSpec expected at least 1 parameters not '$# 1
    [[ $isInitialized == true ]]                    || die ${LINENO} 'Error: you need to run init fuction at beginning' 1
    [[ -n "$1" ]]                && comment="$1"    || die ${LINENO} 'udpadeSpec expected a comment as second parameter' 1
    shift
    [[ $verbose == true ]] && echo "Updating spec file: ${specFile}"
    
    if [[ -n "$@" ]]; then
        [[ $(( $# % 2 )) ]]  && parameters=( "$@" ) || die ${LINENO} 'udpadeSpec expected a paired numbers of parameters' 1
        
        tmpfile="$(mktemp)"
        
        while read -r line; do
            for ((index=0;  $index < ${#parameters[@]}; index+=2 )); do 
                pattern=${parameters[$index]}
                value=${parameters[$(( $index + 1 ))]}
                
                if [[ -n "${line}" && "${line}" =~ ${pattern} && "${BASH_REMATCH[1]}" != "${value}" ]]; then
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

# getSourcesFiles
# This function is used to get sources files need by reading spec file.
# You do not have need to call it as this function is called by init function.
getSourcesFiles () {
    local line sourceFile url key hashValue varValue varname
    local -A variables
    while read line; do
        if [[ "${line}" =~ ^%global[[:blank:]]+([[:alnum:]_]+)[[:blank:]]+([[:alnum:][:punct:]]+) ]]; then
            varname='%{'"${BASH_REMATCH[1]}"'}'
            varValue="${BASH_REMATCH[2]}"
            if [[ "${varValue}" =~ [[:punct:]] ]]; then
                for key in "${!variables[@]}"; do
                        hashValue=${variables["${key}"]}
                    if [[ "${varValue}" =~ "${key}" ]]; then
                        varValue=${varValue//"${key}"/${hashValue}}
                    fi
                done
            fi
            variables["${varname}"]="${varValue}"
        elif [[ "${line}" =~ ^name:[[:blank:]]+([[:alnum:][:punct:]]+) ]]; then
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

# remoteBuild
# This function is used to do a remote build by using fedpkg tool
# The build is done if package get an update or if variable force is true
# Parameter:
# - comment to use when commiting
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
        edpkg build
        #bodhi -u $login -c "${comment}" -N "${comment}" --type='enhancement' ${package_name}
        popd  1> /dev/null
    else
        echo "${package_name}"' already up to date. Nothing to do.'
    fi
}

# gitGetRepo
# This function is used to download a git repo and to update it from lates commit put by upstream
# Parameter:
# - git url to use
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

# gitExtractSnapDate
# This function is used to get date from the latest commit.
# The date is stored into the global variable 'snapdate'.
gitExtractSnapDate () {
    local date_string
    [[ $# -eq 0 ]]  || die ${LINENO} "gitExtractSnapDate expected 0 parameters not $#" 1
    [[ -e '.git' ]] || die ${LINENO} "Error: is not a git repository" 1
    date_string=$(git log -1 --format="%ci")
    date_string="${date_string%% *}"
    snapdate="${date_string//-/}"
}

# gitExtractRev
# This function is used to get the latest revision.
# The revision is stored into the global variable 'revision'.
gitExtractRev () {
    [[ $# -eq 0 ]]          || die ${LINENO} "gitExtractRev expected 0 parameters not $#" 1
    [[ -e '.git' ]]         || die ${LINENO} "Error: is not a git repository" 1
    [[ $verbose == true ]]  && echo "Extracting $(basename  $(pwd)) archive"
    revision="$(git rev-parse --short HEAD)"
}

# gitArchive
# This function is used to create an archive .tar.xz from a git repo.
# Parameter:
# - root directory to use
# - archive name
# - output dirctory
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

#!/usr/bin/env bash
declare -r -x RPMBUILD=$(readlink -m "${HOME}"'/rpmbuild')
declare -r -x SOURCES=$(readlink -m "${RPMBUILD}"'/SOURCES')
declare -r -x SPECS=$(readlink -m "${RPMBUILD}"'/SPECS')
declare -r -x SRPMS=$(readlink -m "${RPMBUILD}"'/SRPMS')
declare -r -x RPMS=$(readlink -m "${RPMBUILD}"'/RPMS')

declare -r -x RESET="$(tput sgr0)"
declare -r -x BOLD="$(tput bold)"
declare -r -x BLACKF="$(tput setaf 0)"
declare -r -x BLACKB="$(tput setab 0)"
declare -r -x REDF="$(tput setaf 1)"
declare -r -x REDB="$(tput setab 1)"
declare -r -x GREENF="$(tput setaf 2)"
declare -r -x GREENB="$(tput setab 2)"
declare -r -x YELLOWF="$(tput setaf 3)"
declare -r -x YELLOWB="$(tput setab 3)"
declare -r -x BLUEF="$(tput setaf 4)"
declare -r -x BLUEB="$(tput setab 4)"
declare -r -x MAGENTAF="$(tput setaf 5)"
declare -r -x MAGENTAB="$(tput setab 5)"
declare -r -x CYANF="$(tput setaf 6)"
declare -r -x CYANB="$(tput setab 6)"
declare -r -x WHITEF="$(tput setaf 7)"
declare -r -x WHITEB="$(tput setab 7)"

declare scriptFile filename tmp 
declare -x -a branchList=()
declare -x -a tmpBranchList=()
declare -x -A packageBranch=()
declare -x -a forceList=()
declare -x branch
declare -x verbose=false
declare -x force=false
declare -x logDir
declare -x mail
declare -x name
declare -x userstring
declare -x login

usage () {
    local errCode
    [[ $# -eq 1 ]] || die ${LINENO} "usage expected 1 parameters not $#" 1
    errCode="$1"
    echo "$0 [options]"
    echo '    -h --help                             Display this message'
    echo '    -v --verbose                          Increase the verbosity'
    echo '    -f --force                            Build rpm even package do not get an update'
    echo '    -l --login                            Fas user name ( not used yet )'
    echo '    -m --mail                             Mail to put into changelog'
    echo '    -n --name                             Real name to put into changelog'
    echo '    -f --force <package name>             Force to build the given package'
    echo '    -b --branch <script name> <branch>    Specified for a script which branch to use (override branch list)'
    echo '    --branchList <"branch1 branch2 …">    Global branch list to used'
    exit $errCode
}

# configReader
# This function is used to read the config file and set variables automatically.
# You do not have need to call it as this function is called from builder script.
# Parameter:
# - config file to use
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
                    name)          name="${BASH_REMATCH[2]}";;
                    login)         login="${BASH_REMATCH[2]}";;
                    mail)          mail="${BASH_REMATCH[2]}";;
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

if [[ -f "${HOME}"'/.config/builder/config' ]]; then
    configReader "${HOME}"'/.config/builder/config'
elif [[ -f '/etc/builder/config' ]]; then
    configReader '/etc/builder/config'
fi

while [[ -n "$@" ]]; do
    case "$1" in
        -h|--help)      usage 0 ;;
        -v|--verbose)   verbose=true ;;
        -f|--force)     force=true ;;
        -l|--login)     login="$2"; shift ;;
        -m|--mail)      mail="$2"; shift ;;
        -n|--name)      name="$2"; shift ;;
        -b|--branch)    [[ ${packageBranch["$2"]} ]] && packageBranch["$2"]=",$3" || packageBranch["$2"]="$3"; shift ; shift ;;
        --branchList)   branchList+=( "$2" ); shift ;;
        *) echo "Unsuported parameter $1" >&2; usage 1 ;;
    esac
    shift
done

[[ -n "${name}" ]] || { echo 'A real name to put into changelog is required' >&2    ; usage 1; }
[[ -n "${mail}" ]] || { echo 'A mail to put into changelog is required' >&2         ; usage 1; }


for scriptFile in "${RPMBUILD}"/SCRIPT/*.sh; do
    filename=$(basename "${scriptFile}")
    if [[ "${filename}" != 'common.sh' && "${filename}" != 'builder.sh'  ]]; then
        if [[ ${packageBranch["${scriptFile}"]} ]]; then
            tmp=${packageBranch["${scriptFile}"]}
            tmpBranchList=( ${tmp/,/ /} )
        else
            tmpBranchList=( ${branchList[@]} )
        fi
        for branch in "${tmpBranchList[@]}"; do
            logDir="$(mktemp --directory)"
            "${scriptFile}"
            if [[ $? -eq 0 ]]; then
                echo -e "${BOLD}${GREENF}"'[Success] '"${RESET} ${branch} "$( basename "${scriptFile}" .sh )' ( '"${logDir}"' )'
            else
                echo -e "${BOLD}${REDF}"'[Failed]  '${RESET} "${branch} "$( basename "${scriptFile}" .sh )' ( '"${logDir}"' )' >&2
            fi
        done
    fi
done

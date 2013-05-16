#!/usr/bin/env bash
declare scriptFile filename tmp 
declare -x -a branchList=()
declare -x -a tmpBranchList=()
declare -x -A packageBranch=()
declare -x -a forceList=()

. "$(dirname $0)"/common.sh

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
        -l|--login)     LOGIN="$2"; shift ;;
        -m|--mail)      MAIL="$2"; shift ;;
        -n|--name)      NAME="$2"; shift ;;
        -b|--branch)    [[ ${packageBranch["$2"]} ]] && packageBranch["$2"]=",$3" || packageBranch["$2"]="$3"; shift ; shift ;;
        --branchList)   branchList+=( "$2" ); shift ;;
        *) echo "Unsuported parameter $1" >&2; usage 1 ;;
    esac
    shift
done

[[ -n "${NAME}" ]] || { echo 'A real name to put into changelog is required' >&2    ; usage 1; }
[[ -n "${MAIL}" ]] || { echo 'A mail to put into changelog is required' >&2         ; usage 1; }


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
            "${scriptFile}"
            if [[ $? -eq 0 ]]; then
                echo -e ${BOLD}${GREENF}'[Success] '${RESET} "${branch} "$( basename "${scriptFile}" .sh )
            else
                echo -e ${BOLD}${REDF}'[Failed]  '${RESET} "${branch} "$( basename "${scriptFile}" .sh ) >&2
            fi
        done
    fi
done

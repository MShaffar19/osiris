#!/bin/bash
# ===========================================================================
#
#                            PUBLIC DOMAIN NOTICE
#               National Center for Biotechnology Information
#
#  This software/database is a "United States Government Work" under the
#  terms of the United States Copyright Act.  It was written as part of
#  the author's official duties as a United States Government employee and
#  thus cannot be copyrighted.  This software/database is freely available
#  to the public for use. The National Library of Medicine and the U.S.
#  Government have not placed any restriction on its use or reproduction.
#
#  Although all reasonable efforts have been taken to ensure the accuracy
#  and reliability of the software and data, the NLM and the U.S.
#  Government do not and cannot warrant the performance or results that
#  may be obtained by using this software or data. The NLM and the U.S.
#  Government disclaim all warranties, express or implied, including
#  warranties of performance, merchantability or fitness for any particular
#  purpose.
#
#  Please cite the author in any work or product based on this material.
#
#  OSIRIS is a desktop tool working on your computer with your own data.
#  Your sample profile data is processed on your computer and is not sent
#  over the internet.
#
#  For quality monitoring, OSIRIS sends some information about usage
#  statistics  back to NCBI.  This information is limited to use of the
#  tool, without any sample, profile or batch data that would reveal the
#  context of your analysis.  For more details and instructions on opting
#  out, see the Privacy Information section of the OSIRIS User's Guide.
#
# ===========================================================================
#
#  FileName: pinger.vbs
#  Author:   Douglas Hoffman
#
#
#  ncbi pinger for macintosh
#
#

function ECHO2()
{
  echo "$@" 1>&2
}

function CHECKRC()
{
  if test "$1" != "0"; then
    if test "$2" != ""; then
      ECHO2 "$2"
    fi
    exit $1
  fi
}
function FIND()
{
  for x in "/usr/bin" "/bin" "/usr/sbin" "/sbin" ; do
    s="${x}/${1}"
    if test -x "${s}"; then
      echo "${s}"
      return 0
    fi
  done
  s=$(which "$1")
  if test -x "${s}"; then
    echo "${s}"
    return 0
  fi
  return 1
}

function SETUP()
{
  URL="https://www.ncbi.nlm.nih.gov/stat"
  PID=$$
  APP_VER="v0"
  APP_NAME="ncbi pinger"
  BASE_QUERY=""
  STARTTIME=$(date '+%s')
  SESSION_TIME=$(date '+%y%m%d.%H%M%S.')
  NSCURL=$(FIND nscurl)
  CCURL=$(FIND curl)
  SWVERS=$(FIND sw_vers)
  
  if test -x "${SWVERS}" ; then
    eval $( "${SWVERS}" | sed -e 's/:[	 ]*/="/' -e 's/$/"/')
  fi
  ProductName=${ProductName:-Mac OS X}
  ProductVersion=${ProductVersion:-unknown}
  export OSVERSION="${ProductName} ${ProductVersion}"

  if test -x "${CCURL}" ; then
    export CURL="${CCURL}"
    export ARGS="-s -f"
    SCUTIL=$(FIND scutil)
    if test -x "${SCUTIL}" ; then
      HTTPSEnable=""
      HTTPSPort=""
      HTTPSProxy=""
      eval $("${SCUTIL}" --proxy | grep "HTTPS.*:" | sed -e 's/^ *//' -e 's/[ 	]*:[ 	]*/="/' -e 's/$/"/')
      if test "${HTTPSEnable}" = "1" -a "${HTTPSPort}" != "" -a "${HTTPSProxy}" != ""; then
        export https_proxy="http://${HTTPSProxy}:${HTTPSPort}/"
        export http_proxy="${https_proxy}"
      fi
    fi
  elif test -x "${NSCURL}" ; then
    export CURL="${NSCURL}"
    export ARGS=""
  else
    CHECKRC 1 "Cannot find curl, exit $BASH_SOURCE"
  fi
}



function rawurlencode()
{
# https://stackoverflow.com/questions/296536/how-to-urlencode-data-for-curl-command

  local string="${1}"
  local strlen=${#string}
  local encoded=""
  local pos c o

  for (( pos=0 ; pos<strlen ; pos++ )); do
     c=${string:$pos:1}
     case "$c" in
        [-_.~a-zA-Z0-9] ) o="${c}" ;;
        * )               printf -v o '%%%02x' "'$c"
     esac
     encoded+="${o}"
  done
  echo "${encoded}"    # You can either set a return variable (FASTER) 
  REPLY="${encoded}"   #+or echo the result (EASIER)... or both... :p
}

function ADD_PAIR()
{
  local BASE="$1"
  local PAIR=$(rawurlencode "$2" | sed 's/%3[Dd]/=/')
  # decode first equal sign
  if test "$PAIR" = ""; then
    true
  elif test "$(echo \"$PAIR\" | grep '=')" = ""; then
    PAIR="${PAIR}="
  fi
  if test "${BASE}" != "" -a "${PAIR}" != ""; then
    echo "${BASE}&${PAIR}"
  else
    echo "${BASE}${PAIR}"
  fi
}

function PING()
{
  T=$(date '+%s')
  E=$(expr $T - $STARTTIME)
  Q=$(ADD_PAIR "$1" "elapse=${E}")
  echo "$CURL" $ARGS -A "${USER_AGENT}" -o /dev/null "${URL}?${Q}"
  "$CURL" $ARGS -A "${USER_AGENT}" -o /dev/null "${URL}?${Q}"
  CHECKRC $? "${CURL} failed"
}


function MAIN()
{
SETUP

while getopts ":v:a:s:p:" opt ; do
  case $opt in
    a)
        APP_NAME="${OPTARG}"
        BASE_QUERY=$(ADD_PAIR "${BASE_QUERY}" "ncbi_app=${APP_NAME}")
        ;;
    v)
        APP_VER="${OPTARG}"
        BASE_QUERY=$(ADD_PAIR "${BASE_QUERY}" "app_ver=${APP_VER}")
        ;;
    u)
        URL="${OPTARG}"
        ;;
    s)
        BASE_QUERY=$(ADD_PAIR "${BASE_QUERY}" "${OPTARG}")
        ;;
    p)
        PID="${OPTARG}"
        ;;
    *)
       ECHO2 "${opt}: invalid parameter"
       ;;
  esac
done

USER_AGENT="${APP_NAME} ${APP_VER} for ${OSVERSION}"
BASE_QUERY=$(ADD_PAIR "${BASE_QUERY}" "session=${SESSION_TIME}${PID}")
BASE_QUERY=$(ADD_PAIR "${BASE_QUERY}" "os=${OSVERSION}")

PING "${BASE_QUERY}"
Q="${BASE_QUERY}"
CRASH=1
while read x; do
  if test "$x" = "go"; then
    PING "$Q"
    Q="${BASE_QUERY}"
  elif test "$x" = "q"; then
    # calling progam sent "q" to quit
    # therefore didn't crash
    CRASH=0
    break
  else
    Q=$(ADD_PAIR "${Q}" "$x")
  fi
done
if test "$CRASH" = "1"; then
  # calling program did not send "1" to quit
  Q=$(ADD_PAIR "${Q}" "crash=1")
fi
Q=$(ADD_PAIR "${Q}" "done=1")
PING "$Q"

}
MAIN "$@"

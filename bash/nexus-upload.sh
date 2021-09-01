#!/usr/bin/env bash
# Copyright (c) 2021, University Corporation for Atmospheric Research/Unidata
# All rights reserved.
# Released under the BSD-3 license

set -e

usage() {
  cat <<EOM
Minimum Usage:
  $(basename "$0") -t <docs|downloads> -u USERNAME -o PROJECT_NAME -v PROJECT_VERSION file1...
Use $0 -h for more details.
EOM
}

help() {
  cat <<EOM

Usage:
  $(basename "$0") -t <docs|downloads> -u USERNAME -o PROJECT_NAME -v PROJECT_VERSION [-p PASSWORD] [-c NEW_FILENAME] [-nhf] file...

Description:
  $(basename "$0") - upload one or more files to the Unidata Nexus artifacts server.

  Files will be uploaded to https://artifacts.unidata.ucar.edu/repository/<raw-repo-name>/<verson>/,
  where <raw-repo-name> is determined by the upload type (-t) and project name (-o) flags, and version is
  set by the project version (-v) flag. If the options password flag (-p) is not supplied, a password prompt will
  display.

  For example, upload type "docs", project name "netcdf-java", and version "5.4.2" will upload files match by the
  glob to:

    https://artifacts.unidata.ucar.edu/repository/docs-netcdf-java/5.4.2/

  The naming structure under <raw-repo-name>/<version> will match the path used by the input file.
  so if the file path passed to a script is ./a/b/file.txt, then the command:

    $(basename "$0") -t downloads -u username -o project -v 1.2.3 ./a/b/file.txt

  will create the following file on the nexus artifacts server:

    https://artifacts.unidata.ucar.edu/repository/docs-project/1.2.3/a/b/file.txt 

  If the path should not be reflected on the server side, the then use filename only flag (-f).

  For example, the command:

    $(basename "$0") -t downloads -u username -o project -v 1.2.3 -f ./a/b/file.txt

  will create the following file on the nexus artifacts server:

    https://artifacts.unidata.ucar.edu/repository/docs-project/1.2.3/file.txt 

  If the directory ./a/b contains the following tarballs:
    a/
      b/
        tarball-1.tar.bz2
        tarball-2.tar.bz2
        tarball-3.tar.bz2

  The command:

    $(basename "$0") -t downloads -u username -o project -v 1.2.3 ./a/b/*.tar.bz2

  will create the following three files on the nexus artifacts server:

    https://artifacts.unidata.ucar.edu/repository/docs-project/1.2.3/a/b/tarball-1.tar.bz2
    https://artifacts.unidata.ucar.edu/repository/docs-project/1.2.3/a/b/tarball-2.tar.bz2
    https://artifacts.unidata.ucar.edu/repository/docs-project/1.2.3/a/b/tarball-3tar.bz2

  Using the -f flag with the previous command would result in the following files on the nexus artifacts server:

    https://artifacts.unidata.ucar.edu/repository/docs-project/1.2.3/tarball-1.tar.bz2
    https://artifacts.unidata.ucar.edu/repository/docs-project/1.2.3/tarball-2.tar.bz2
    https://artifacts.unidata.ucar.edu/repository/docs-project/1.2.3/tarball-3tar.bz2

  If you would like the name of the file on the nexus artifacts server to be different than the local
  file you are uploading, use the change filename flag (-c).

  For example, the command:

    $(basename "$0") -t downloads -u username -o project -v 1.2.3 -c newFile.txt file.txt

  will create the following file on the nexus artifacts server:

    https://artifacts.unidata.ucar.edu/repository/docs-project/1.2.3/newFile.txt 

  To upload the entire contents of a directory, pair this script with the find command using and pipe.
  For example, to upload every file found under the ./docs/ directory, use the command:

    find ./docs -type f | $(basename "$0") -t downloads -u username -o project -v 1.2.3

Required flags:
  -t: upload type
      must be either docs or downloads
  -u: nexus username
  -o: project name
  -v: project version

Optional flags:
  -n: dry-run
      echo upload command, but do not execute
  -f: use filename only
      do not preserve local path in the server side path
  -c: change the filename on the server side (incompatible when uploading multiple files)
  -h: help
      display this help message

EOM
}

echo_error() {
  echo "$*" >>/dev/stderr
}

if [[ $# -eq 0 ]]; then
  usage
  exit 1
fi

TRUE="true"
FALSE="false"
VALID_RAW_REPO_TYPES=( "docs" "downloads" )
VALID_PROJECTS=( "idv" "ldm" "netcdf-c" "netcdf-cxx" "netcdf-fortran"
                 "netcdf-java" "rosetta" "ncml" "tds" "udunits" "awips2" )

# Validate variable against a set of known valid values based on the variable name
#
# A variable named "INPUT_NAME" will be compared to the list of valid values contained in
# the aray named "VALID_INPUT_NAMES"
#
# args: INPUT_NAME
# 
# example:
# validate "TYPE"
# Will compare the value of the variable ${TYPE} against a set of valid values contained in
# the array ${VALID_TYPES}
#
validate () {
  INPUT_NAME=${1}
  VALUE_TO_VALIDATE="${!INPUT_NAME}"
  VALID_VALUES_ARRAY_NAME="VALID_${INPUT_NAME}S"
  VALID_VALUES_ARRAY_NAME="${VALID_VALUES_ARRAY_NAME}[@]"
  VALID_VALUES_ARRAY=("${!VALID_VALUES_ARRAY_NAME}")
  if [[ ! " ${VALID_VALUES_ARRAY[@]} " =~ " ${VALUE_TO_VALIDATE} " ]]; then
    VALID=$(printf " || %s" "${VALID_VALUES_ARRAY[@]}")
    VALID=${VALID:4}
    echo_error "Invalid value \"${VALUE_TO_VALIDATE}\". ${INPUT_NAME} must be one of [ ${VALID} ]"
    usage
    exit 1
  fi
}

USERNAME=
PASSWORD=
PROJECT=
RAW_REPO_TYPE=
VERSION=
DRYRUN="${FALSE}"
FILEONLY="${FALSE}"
NEW_FILENAME=

while getopts "u:o:t:v:p::c:fnh" FLAG; do
  case "$FLAG" in
  u)
     USERNAME="$OPTARG"
     ;;
  o)
     PROJECT="$OPTARG"
     ;;
  t)
     RAW_REPO_TYPE="$OPTARG"
     ;;
  v)
     VERSION="$OPTARG"
     ;;
  p)
     PASSWORD="$OPTARG"
     ;;
  n)
     DRYRUN="${TRUE}"
     ;;
  f)
     FILEONLY="${TRUE}"
     ;;
  c)
     NEW_FILENAME="$OPTARG"
     ;;
  h)
     help
     exit 0
     ;;
  ?)
     usage
     exit 1
     ;;
  esac
done

validate "TYPE"
validate "PROJECT"

shift $((OPTIND-1))

if [[ -p /dev/stdin ]]; then
  # input from pipe
  EXPRESSION=$(< /dev/stdin)
else
  # input as a list of files as arguments
  EXPRESSION="$*"
fi

if [[ $# > 1 ]] && [[ ${NEW_FILENAME} != "" ]]; then
  echo "Cannot use the change filename (-c flag) with multiple file uploads" 
  exit 1
fi

REPO="https://artifacts.unidata.ucar.edu/repository/${RAW_REPO_TYPE}-${PROJECT}"

if [[ -z ${PASSWORD} ]]; then
  read -sp 'Please enter your artifacts server password: ' PASSWORD </dev/tty
  echo ""
fi

for F in ${EXPRESSION[@]}; do
  if [[ -f "$F" ]]; then
    if [[ "${FILEONLY}" = "${TRUE}" ]];then
      if [[ "${NEW_FILENAME}" != "" ]];then
        SERVER_FILENAME=$(basename "${NEW_FILENAME}")
      else
        SERVER_FILENAME=$(basename "${F}")
      fi
    else
      if [[ "${NEW_FILENAME}" != "" ]];then
        SERVER_FILENAME="${NEW_FILENAME}"
      else
        if [[ ${F} = /* ]]; then
          SERVER_FILENAME="${F:1}"
        elif [[ ${F} = ./* ]]; then
          SERVER_FILENAME="${F:2}"
        else
          SERVER_FILENAME="${F}"
        fi
      fi
    fi
    echo "Uploading ${F}"
    URL="${REPO}/${PROJECT}/${VERSION}/${SERVER_FILENAME}"
    CURL_COMMAND="curl -w httpcode=%{http_code}"
    UPLOAD_OPT="--upload-file "${F}" "${URL}""
    if [[ ${DRYRUN} = "${TRUE}" ]]; then
      echo "${CURL_COMMAND} -u ${USERNAME}:***** ${UPLOAD_OPT}"
    else
      RETURN_CODE=0
      OUTPUT=$(${CURL_COMMAND} -u "${USERNAME}":"${PASSWORD}" ${UPLOAD_OPT} 2> /dev/null) || RETURN_CODE=$?
      if [[ ${RETURN_CODE} -ne 0 ]]; then
        echo_error "Curl command failed with return code - ${RETURN_CODE}"
        exit 1
      else
        # Check http code for curl operation/response in  CURL_OUTPUT"
        HTTP_STATUS_CODE=$(echo "${OUTPUT}" | sed -e 's/.*\httpcode=//')
        if [[ ${HTTP_STATUS_CODE} -gt 300 || ${HTTP_STATUS_CODE} -le 200 ]]; then
          echo_error "Upload to ${URL} failed."
          echo_error "Server HTTP response code - ${HTTP_STATUS_CODE}"
          exit 1
        fi
      fi
    fi
  fi
done


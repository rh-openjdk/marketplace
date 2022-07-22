#!/bin/bash

# Copyright (C) 2022 Red Hat, Inc.
# Written by Andrew Hughes <gnu.andrew@redhat.com>, 2022
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

REPO=${1}
JAVA_TEST=TestTimestamp.java
JAVA_CLASS_NAME=$(echo $(basename ${JAVA_TEST})|sed "s|\.java||")
JSON_TOOL=$(which json_verify)
OPENSSL=$(which openssl)
BASE64=$(which base64)
DATE=$(which date)

if test "x${JAVA_HOME}" = "x"; then
    JAVAC=$(which javac)
    JAVA=$(which java)
else
    echo "Found JAVA_HOME defined as ${JAVA_HOME}; using it for java and javac";
    JAVAC=${JAVA_HOME}/bin/javac
    JAVA=${JAVA_HOME}/bin/java
fi

if test "x${REPO}" = "x"; then
    REPO=${PWD}
    echo "No directory specified; using ${REPO}";
fi

# Handle relative paths to the script
if echo ${0} | grep '^/' ; then
    SCRIPT_DIR=$(dirname ${0})
else
    SCRIPT_DIR=${PWD}/$(dirname ${0})
fi

if test -z "${JSON_TOOL}" -o ! -x "${JSON_TOOL}" ; then
    echo "JSON verifier not found.";
    exit 1;
fi

if test -z "${OPENSSL}" -o ! -x "${OPENSSL}" ; then
    echo "OpenSSL not found.";
    exit 2;
fi

if test -z "${BASE64}" -o ! -x "${BASE64}" ; then
    echo "Base64 decoder not found.";
    exit 3;
fi

if test -z "${JAVAC}" -o ! -x "${JAVAC}" ; then
    echo "Java compiler not found.";
    exit 4;
fi

if test -z "${JAVA}" -o ! -x "${JAVA}" ; then
    echo "Java virtual machine not found.";
    exit 5;
fi

if test -z "${DATE}" -o ! -x "${DATE}" ; then
    echo "date not found.";
    exit 6;
fi

PUBKEY=${REPO}/publisher-pub.pem
echo "Public key: ${PUBKEY}"
if [ ! -f ${PUBKEY} ] ; then
    echo "Could not find public key ${PUBKEY}";
    echo "${0} <JSON_REPO>"
    exit 7;
fi

if test "x${TMPDIR}" = "x"; then
    TMPDIR=/tmp;
fi

failure=0
for file in $(find ${REPO} -name '*.json'); do
    echo "Verifying JSON file ${file}...";
    if ! cat ${file} | ${JSON_TOOL} ; then
	echo "FAILURE: Unable to parse JSON file ${file}";
	(( failure++ ))
    fi
    # Timestamps must be in UTC ISO-8601 format i.e.
    TIMESTAMP_LIST=$(grep 'timestamp' ${file} |cut -d '"' -f 4)
    if [ -n "${TIMESTAMP_LIST}" ] ; then
	echo "Verifying timestamps in JSON file ${file} are in the form %Y-%m-%dT%H:%M:%SZ...";
	echo "Current timestamp would be $(${DATE} +%Y-%m-%dT%H:%M:%SZ)";
	pushd ${TMPDIR}
	if [ ! -f ${SCRIPT_DIR}/${JAVA_TEST} ] ; then
	    echo "Could not find ${JAVA_TEST} in ${SCRIPT_DIR}.";
	    exit 7;
	fi
	if [ ! -f ${JAVA_CLASS_NAME}.class ] ; then
	    if ! ${JAVAC} -d . ${SCRIPT_DIR}/${JAVA_TEST} ; then
		echo "Could not compile ${JAVA_TEST}";
		exit 8;
	    fi
	fi
	${JAVA} ${JAVA_CLASS_NAME} ${TIMESTAMP_LIST}
	timestamp_failures=$(( ${?} - 1 ))
	if [ ${timestamp_failures} -ge 0 ] ; then
	    echo "FAILURE: Unable to decode timestamps in ${file}";
	    failure=$(( ${failure} + ${timestamp_failures} ))
	    # Attempt to get date to fix it for us
	    echo "Attempting to use ${DATE} to get suggested fixes...";
	    for timestamp in ${TIMESTAMP_LIST} ; do
		echo -e "\t${timestamp} should be $(${DATE} -u +%Y-%m-%dT%H:%M:%SZ --date=${timestamp})";
	    done
	fi
	popd
    fi
    echo "Verifying signature of JSON file ${file}.sha256.sign...";
    if ! ${BASE64} -d ${file}.sha256.sign > ${TMPDIR}/sig.$$ ; then
	echo "FAILURE: Unable to decode base64 signature in ${file}.sha256.sign";
	(( failure++ ))
    fi
    if ! ${OPENSSL} dgst -sha256 -verify ${PUBKEY} -signature ${TMPDIR}/sig.$$ ${file} ; then
	echo "FAILURE: Unable to verify signature in ${TMPDIR}/sig.$$ for ${file}";
	(( failure++ ))
    fi
    rm ${TMPDIR}/sig.$$
done
rm ${TMPDIR}/${JAVA_CLASS_NAME}.class

if test ${failure} -gt 0; then
    echo "${failure} failures."
else
    echo "All tests successful.";
fi
exit ${failure};

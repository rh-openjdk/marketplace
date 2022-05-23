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
JSON_TOOL=$(which json_verify)
OPENSSL=$(which openssl)
BASE64=$(which base64)

if test "x${REPO}" = "x"; then
    REPO=${PWD}
    echo "No directory specified; using ${REPO}";
fi

if [ ! -x ${JSON_TOOL} ] ; then
    echo "JSON verifier not found.";
    exit 1;
fi

if [ ! -x ${OPENSSL} ] ; then
    echo "OpenSSL not found.";
    exit 2;
fi

if [ ! -x ${BASE64} ] ; then
    echo "Base64 decoder not found.";
    exit 3;
fi

PUBKEY=${REPO}/publisher-pub.pem
echo "Public key: ${PUBKEY}"
if [ ! -f ${PUBKEY} ] ; then
    echo "Could not find public key ${PUBKEY}";
    echo "${0} <JSON_REPO>"
    exit 4;
fi

if test "x${TMPDIR}" = "x"; then
    TMPDIR=/tmp;
fi

for file in $(find ${REPO} -name '*.json'); do
    echo "Verifying JSON file ${file}...";
    cat ${file} | ${JSON_TOOL}
    echo "Verifying signature of JSON file ${file}.sha256.sign...";
    ${BASE64} -d ${file}.sha256.sign > ${TMPDIR}/sig.$$
    ${OPENSSL} dgst -sha256 -verify ${PUBKEY} -signature ${TMPDIR}/sig.$$ ${file}
    rm ${TMPDIR}/sig.$$
done

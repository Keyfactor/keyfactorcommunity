#!/bin/bash

INPUT_HOSTNAME="127.0.0.1"
INPUT_CERT_PROFILE="SERVER"
INPUT_END_ENTITY_PROFILE="EMPTY"
INPUT_CA_NAME="ManagementCA"
INPUT_USERNAME="pkcs10enroll_user"
enrollment_code="foo123"

help () {
  echo "Usage: `basename $0` options"
  echo "-c : the csr file"
  echo "-P : the p12 file to authenticate with"
  echo "-s : the p12 file password"
  echo "-t : the Trust chain file for the TLS certificate"
  echo "-H : the EJBCA FQDN or IP Address"
  echo "-u : the username of the entity created in EJBCA"
  echo "-p : the certificate profile name"
  echo "-e : the end entity profile name"
  echo "-n : the CA name"
  echo "
This script will use the EJBCA REST API PKCS10Enroll endpoint to submit CSR's for a certificate
"
}

while getopts "c:P:H:s:t:u:p:e:n:xh" optname ; do
  case $optname in
    c )
      INPUT_CSR_FILE=$OPTARG ;;
    P )
      INPUT_P12_CREDENTIAL=$OPTARG ;;
    s )
      INPUT_P12_CREDENTIAL_PASSWD=$OPTARG ;;
    t )
      INPUT_TRUST_CHAIN=$OPTARG ;;
    H )
      INPUT_HOSTNAME=$OPTARG ;;
    u )
      INPUT_USERNAME=$OPTARG ;;
    p )
      INPUT_CERT_PROFILE=$OPTARG ;;
    e )
      INPUT_END_ENTITY_PROFILE=$OPTARG ;;
    n )
      INPUT_CA_NAME=$OPTARG ;;
    x )
      set -x ;;
    h )
      help ; exit 0 ;;
    ? )
      echo "Unknown option $OPTARG." ; help ; exit 1 ;;
    : )
      echo "No argument value for option $OPTARG." ; help ; exit 1 ;;
    * )
      echo "Unknown error while processing options." ;;
  esac
done

if [ ! -f "$INPUT_CSR_FILE" ]; then
    echo "Please try again with a csr"
    exit 1
fi

if [ ! -f "$INPUT_P12_CREDENTIAL" ]; then
    echo "Please specify a P12 file"
    exit 1
fi

csr="$(cat ${INPUT_CSR_FILE})"

template='{"certificate_request":$csr, "certificate_profile_name":$cp, "end_entity_profile_name":$eep, "certificate_authority_name":$ca, "username":$ee, "password":$pwd}'
json_payload=$(jq -n \
    --arg csr "$csr" \
    --arg cp "$INPUT_CERT_PROFILE" \
    --arg eep "$INPUT_END_ENTITY_PROFILE" \
    --arg ca "$INPUT_CA_NAME" \
    --arg ee "$INPUT_USERNAME" \
    --arg pwd "$enrollment_code" \
    "$template")

if [ -f "$INPUT_TRUST_CHAIN" ]; then
    curl -X POST -s --cacert "$INPUT_TRUST_CHAIN" \
    --cert-type P12 \
    --cert "$INPUT_P12_CREDENTIAL:$INPUT_P12_CREDENTIAL_PASSWD" \
    -H 'Content-Type: application/json' \
    --data "$json_payload" \
    "https://${INPUT_HOSTNAME}/ejbca/ejbca-rest-api/v1/certificate/pkcs10enroll" \
    | jq -r .certificate | base64 -d > "${INPUT_USERNAME}-der.crt"
else
    curl -X POST -s \
    --cert-type P12 \
    --cert "$INPUT_P12_CREDENTIAL:$INPUT_P12_CREDENTIAL_PASSWD" \
    -H 'Content-Type: application/json' \
    --data "$json_payload" \
    "https://${INPUT_HOSTNAME}/ejbca/ejbca-rest-api/v1/certificate/pkcs10enroll" \
    | jq -r .certificate | base64 -d > "${INPUT_USERNAME}-der.crt"
fi

openssl x509 -inform DER -in "${INPUT_USERNAME}-der.crt" -outform PEM -out "${INPUT_USERNAME}.crt"

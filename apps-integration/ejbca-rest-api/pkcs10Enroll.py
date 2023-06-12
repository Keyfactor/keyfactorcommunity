#!/usr/bin/python3

import argparse
import json
from requests import post

def pkcs10enroll(InputCsrFile, caHost, trustChainFile, clientCrt, clientKey, certProfile, eeProfile, caName, userName):
    
    InputCsrFile = InputCsrFile
    caHost = caHost
    trustChainFile = trustChainFile
    clientCrt = clientCrt
    clientKey = clientKey
    certProfile = certProfile
    eeProfile = eeProfile
    caName = caName
    userName = userName

    csr_file = open(InputCsrFile, mode='r')
    csr = csr_file.read()
    csr_file.close()
     
    print(csr)
    
    postURL = 'https://' + caHost + '/ejbca/ejbca-rest-api/v1/certificate/pkcs10enroll'
    
    response = post(postURL,
        json={
          "certificate_request": csr,
          "certificate_profile_name": certProfile,
          "end_entity_profile_name": eeProfile,
          "certificate_authority_name": caName,
          "username": userName,
          "password": "foo123"
        },
        headers={
            'content-type': 'application/json'
        },
        verify=trustChainFile,
        cert=(clientCrt, clientKey))
     
    print (response.content)
    print(json.dumps(json.loads(response.content), indent=4, sort_keys=True))
     
    json_resp = response.json()
     
    cert = json_resp['certificate']
     
    #reconstruct certificate from json array
    pem = "-----BEGIN CERTIFICATE-----"
    for i in range(len(cert)):
        if i % 64 == 0:
            pem += "\n"
        pem += cert[i]
     
    pem += "\n-----END CERTIFICATE-----"
     
    output_cert = json_resp['serial_number'] + ".pem"
    out_file = open(output_cert, "w")
    out_file.write(pem)
    out_file.close()


if __name__ == '__main__':

    parser = argparse.ArgumentParser(description="Issue certificate with EJBCA REST APKI PKCS10enroll")
    parser.add_argument("-c", help="the csr file")
    parser.add_argument("-C", help="the RA cert file to authenticate with")
    parser.add_argument("-k", help="the RA key file to authenticate with")
    parser.add_argument("-t", help="the Trust chain file for the TLS certificate")
    parser.add_argument("-H", help="the hostname or IP address of EJBCA")
    parser.add_argument("-u", help="the username of the entity created in EJBCA")
    parser.add_argument("-p", default="SERVER", help="the certificate profile name")
    parser.add_argument("-e", default="EMPTY", help="the end entity profile name")
    parser.add_argument("-n", default="ManagementCA", help="the CA name")
    args = parser.parse_args()
    
    pkcs10enroll(args.c, args.H, args.t, args.C, args.k, args.p, args.e, args.n, args.u)

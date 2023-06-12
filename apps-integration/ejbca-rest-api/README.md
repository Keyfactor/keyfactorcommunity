![Keyfactor Community](../../keyfactor_community_logo.png)
# EJBCA REST API for Certificate Enrollment
The sample scripts can be use to enroll for a certificate using the EJBCA REST API. 

## Prequisites
You must have the following prequisites met to use these scripts:

- EJBCA configured with a certificate profile, end entity profile, CA, role, etc to issue certificates
- P12 file that is permitted in an EJBCA role to issue an End Entity 
- Linux host to run the Python or shell script
- Python, Python Request, curl, jq, installed on the Linux host


## Getting Started
To use these scripts generate a private key and a Certificate Signing Request (CSR) with OpenSSL.  

### Split P12 File for Python
A certificate and private key are required to authenticate to the EJBCA REST API. The Python script requires the key and certificate in separate files. The steps in this section can be skipped if trying to enroll with the shell script.

1. Export the private key from the P12 file
```bash
openssl pkcs12 -in keyfactorCommunityRA.p12 -out keyfactorCommunityRA.key -nodes -nocerts
```
2. Enter the password for the P12 file

3. Export the certificate from the P12 file
```bash
openssl pkcs12 -in keyfactorCommunityRA.p12 -out keyfactorCommunityRA.pem -nokeys
```
4. Enter the password for the P12 file 

### Create Private Key and CSR
Use an OpenSSL configuration file to easily include the fields in the CSR which are desired:

1. Create the OpenSSL configuration file

```bash
vim server-01.conf

```
2. Add the following as an example. Tweak or modify to your desire

```bash
[ req ]
distinguished_name = req_distinguished_name
req_extensions = req_ext
prompt = no

[ req_distinguished_name ]
countryName = SE
organizationName = Keyfactor Community
commonName = server-01.test
 
[ req_ext ]
subjectAltName = @alt_names
 
[alt_names]
DNS.1 = server-01

```

3. Save and close the file

#### Generate RSA Key & CSR
To generate a private key and CSR using RSA use the following:

1. Generate the private key and CSR with OpenSSL
```bash
openssl req -new -nodes -newkey rsa:2048 -keyout server-01.key -sha256 -out server-01.csr -config server-01.conf 
```

#### Generate EC Key & CSR

1. Generate the EC key
```bash
openssl ecparam -name prime256v1 -genkey -noout -out server-01.key
```

2. Generate the CSR 
```bash
openssl req -new -sha256 -key server-01.key -out server-01.csr -config server-01.conf
```

### Python Enrollment with pkcs10Enroll.py
The following information is needed to enroll with the python script:

- CA URL, e.g., ejbca-node1
- CA chain file which contains the CA certificate files that issued the TLS certificate to the EJBCA instance, e.g., ManagementCA.pem
- Credential Certificate file, e.g., keyfactorCommunityRA.pem
- Credential Key file, e.g., keyfactorCommunityRA.key
- CSR file, e.g., server-01.csr
- CA Name defined in EJBCA, e.g., MyPKISubCA-G1
- Certificate Profile name, e.g., "TLS Server Profile"
- End Entity Profile name, e.g., "TLS Server Profile"
- Username, can be the same as the common name or subject alt name or whatever you would like to use, e.g., server-01

1. Enroll for a certificate using the python script
```bash
./pkcs10Enroll.py -c server-01.csr -C keyfactorCommunityRA.pem \
-k keyfactorCommunityRA.key -t ManagementCA.pem -H ejbca-node1 -u server-01 \
-p "TLS Server Profile" -e "TLS Server Profile" -n MyPKISubCA-G1
```

### Shell Enrollment with pkcs10Enroll.sh
The following information is needed to enroll with the shell script:

- CA URL, e.g., ejbca-node1
- CA chain file which contains the CA certificate files that issued the TLS certificate to the EJBCA instance, e.g., ManagementCA.pem
- Credential P12 file, e.g., keyfactorCommunityRA.12
- Credential P12 file password, e.g., foo123
- CSR file, e.g., server-01.csr
- CA Name defined in EJBCA, e.g., MyPKISubCA-G1
- Certificate Profile name, e.g., "TLS Server Profile"
- End Entity Profile name, e.g., "TLS Server Profile"
- Username, can be the same as the common name or subject alt name or whatever you would like to use, e.g., server-01

1. Enroll for a certificate using the python script
```bash
./pkcs10Enroll.sh -c server-01.csr -P keyfactorCommunityRA.p12 \
-s foo123 -t ManagementCA.pem -H ejbca-node1 -u server-01 \
-p "TLS Server Profile" -e "TLS Server Profile" -n MyPKISubCA-G1
```

### Parse the Certificate
Once the certificate is issued using EJBCA REST API the certificate is ready to use. OpenSSL can parse the certificate to review the contents. In this example the certficate file is called `server-01.crt`, however update the file name accordingly to review the certificate of interest.

1. Parse the certificate with OpenSSL
```bash
openssl x509 -text -noout -in server-01.crt
```

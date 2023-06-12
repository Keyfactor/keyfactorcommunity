FROM registry.primekey.com/primekey/ejbca-ee

USER root

RUN yum install -y which &&\
    mkdir /opt/pkcs11

COPY pkcs11/mpcm-pkcs11.conf /opt/pkcs11/
COPY pkcs11/libcmapi.so.1.6.0 /usr/lib64
COPY pkcs11/libmpcm-pkcs11.so /usr/lib64
COPY ejbca/web.properties /etc/ejbca/conf/

ENV MPCM_PKCS11_CONFIG_PATH /opt/pkcs11/mpcm-pkcs11.conf


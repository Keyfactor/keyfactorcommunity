FROM almalinux:latest AS builder

WORKDIR /build

RUN dnf -y update && \
    dnf -y install 'dnf-command(config-manager)' && \
    dnf -y config-manager --set-enabled crb && \
    dnf -y groupinstall "Development Tools" && \
    dnf -y install openssl-devel automake autoconf libtool pkgconfig pcsc-lite-devel && \
    curl --silent -D - -L "https://github.com/CardContact/sc-hsm-embedded/archive/refs/heads/master.zip" -o sc-hsm-pkcs11.zip && \
    unzip sc-hsm-pkcs11.zip && \
    cd sc-hsm-embedded-master && \
    autoreconf -fis && \
    ./configure --prefix=/usr && \
    make -s && \
    make -s install

FROM keyfactor/ejbca-ce:latest

USER 0:0

COPY --from=builder --chown=10001:0  /usr/lib64/libsc-hsm-pkcs11.so     /usr/lib64/pkcs11/libsc-hsm-pkcs11.so
COPY sc-hsm.conf /etc/pkcs11/modules/sc-hsm.conf

RUN microdnf -y update && \
    microdnf -y install pcsc-lite-libs

USER 10001:0

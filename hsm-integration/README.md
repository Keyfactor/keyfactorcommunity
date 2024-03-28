# HSM Integrations

## Drivers for Hardware Security Module (HSM) integration

The HSM PKCS#11 drivers are usually used with specific approved versions, and tested with the deployed HSM firmware version. Therefore it is difficult to include the correct drivers for specific users by default in containers. In addition, HSM manufacturer license may not allow to bundle and re-distribute the drivers with our containers.

With the above considerations, there is a need to be able to add specific HSM drivers to pre-packaged containers in an easy way.

### Non-PKCS#11 application level drivers

EJBCA EE supports both Azure Key Vault and AWS KMS via CryptoTokens and these can be configured via the UI without any additional rebuild.

### Adding PKCS#11 driver to another file system layer

By taking a release container and adding the PKCS#11 `.so` to the image, you can enable the use of the HSM driver.

This requires:
* a rebuild of the deployed image for every update of either the application or the HSM driver
* that the HSM library works with current OS libraries in the application release
* that the HSM library works with low privileges assigned to the application image at runtime

En examle Dockerfile to copy SoftHSM drivers into the release container, keeping the binaries in the container, but you can volume mount the token library to be used peristent from multiple containers. See also sub folders of this repository for other examples.

```
FROM centos:7 AS builder

WORKDIR /build
# docker build -t ejbca-ce-softhsm:test -f Containerfile.sh .
# Copy the configuration file into the container
COPY softhsm2.conf /etc/softhsm2.conf

RUN yum -y update && \
    yum -y groupinstall "Development Tools" && \
    yum -y install openssl-devel automake autoconf libtool pkgconfig openssl-devel && \
    curl --silent -D - -L "https://github.com/opendnssec/SoftHSMv2/archive/refs/tags/2.6.1.tar.gz" -o SoftHSMv2-current.tar.gz && \
    mkdir -p /build/softhsmv2 && \
    tar -xf SoftHSMv2-current.tar.gz -C "/build/softhsmv2" --strip-components=1 && \
    cd softhsmv2/ && \
    ./autogen.sh && \
    ./configure --disable-non-paged-memory --prefix=/usr && \
    make -s && \
    make -s install && \
    # Create the directory for the tokens
    mkdir -p /var/lib/softhsm/tokens && \
    chgrp -R 0   /var/lib/softhsm/ /usr/lib/softhsm/ /etc/softhsm2.conf && \
    chmod -R g=u /var/lib/softhsm/ /usr/lib/softhsm/ /etc/softhsm2.conf && \
    chown -R 10001:0 /var/lib/softhsm/tokens

FROM keyfactor/ejbca-ce:latest

USER 0:0

COPY --from=builder --chown=10001:0  /var/lib/softhsm/                  /var/lib/softhsm/
COPY --from=builder --chown=10001:0  /usr/lib/softhsm/libsofthsm2.so    /usr/lib/softhsm/libsofthsm2.so
COPY --from=builder --chown=10001:0  /usr/bin/softhsm2-keyconv          /usr/bin/softhsm2-keyconv
COPY --from=builder --chown=10001:0  /usr/bin/softhsm2-util             /usr/bin/softhsm2-util
COPY --from=builder --chown=10001:0  /usr/bin/softhsm2-dump-file        /usr/bin/softhsm2-dump-file
COPY --from=builder --chown=10001:0  /etc/softhsm2.conf                 /etc/softhsm2.conf

# Create a volume for the tokens
VOLUME /var/lib/softhsm/tokens

# Set the environment variable for the configuration file
ENV SOFTHSM2_CONF="/etc/softhsm2.conf"

USER 10001:0
```
To create some slots in SoftHSM, the command is like this:
```
softhsm2-util --init-token --free --label RootCA --so-pin foo123 --pin foo123
softhsm2-util --init-token --free --label SubCA --so-pin foo123 --pin foo123
```

The container file above would be very similar to install a PKCS11 client from a HSM vendor and then copy the pieces needed to the EJBCA container.

### Side-car pattern for Hardware Security Module (HSM) integration

EE application users can leverage a proprietary module packaged as a container to invoke the HSM specific PKCS#11 library over (Pod-local) network. This enables rolling updates of either hsm-driver or application container without the risk of application container library changes breaking the HSM driver.

<a href="hsm-driver-pattern.png"><img src="hsm-driver-pattern.png" width="720"/></a>

This enables rolling updates of either hsm-driver or application container without the risk of application container library changes breaking the HSM driver.

See the provided hsm-driver examples on how this can be used.

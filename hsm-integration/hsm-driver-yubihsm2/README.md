![Keyfactor Community](../keyfactor_community_logo.png)

# EJBCA EE Container integration with YubiHSM2

## Overview

This example highlights building a side-car hsm-driver container on top of PrimeKey P11Proxy HSM base-driver, adding [YubiHSM2](https://www.yubico.com/products/hardware-security-module/) libraries and scripts.

YubiHSM2 Connector represents the 'main uplink' to the physical USB HSM device, referenced from within the HSM-driver container. The Connector can be running on the same host or on a different one. It can also be running on an additional container layer.

## Deployment parameters

The following environment variables will change the driver container behavior though the HSM config file:

- YUBIHSM_CONNECTOR: Address & port to YubiHSM2 Connector
    - Example: http://192.168.x.xxx:12345
    - Default = http://localhost:12345
- YUBIHSM_DEBUG: Set *true* to enable DEBUG level log
    - Default: disabled
- YUBIHSM_STDOUT: Set *true* to log everything to stdout
    - Default: disabled (stderr)
- YUBIHSM_DINOUT: Set *true* to enable function tracing (ingress/egress)
    - Default: disabled
- YUBIHSM_LIBDEBUG: Set *true* to enable libyubihsm debug output
    - Default: disabled
- YUBIHSM_CACERT: Enables HTTPS validation
    - The value translates to a path at the container, e.g. /tmp/cacert.pem
    - Default: disabled
- YUBIHSM_PROXY: Add a proxy address
    - Example: http://proxyserver.local.com:8080
    - Default: disabled
- YUBIHSM_TIMEOUT: Number of *seconds* for the initial connection to the Connector
    - Must be a number
    - Default: disabled

Refer to [Yubico developers site](https://developers.yubico.com/YubiHSM2/Component_Reference/PKCS_11/) for more info about the configuration file.

## Deployment example

Find docker-compose.yml that runs 2 layers while building one to be the side-car container. 

Other layers can be added, i.e. for using an external database, DNS, reverse proxy, etc. or/and using YubiHSM Connector as a container as well.

This assumes the Connector resides on the docker host (or a remote reachable machine):
1. On the Connector host run with the network IP: `yubihsm-connector -l 192.168.x.xxx:12345`
2. On the docker host, update the environment variables and run: `docker-compose up` or `docker compose up`

## Troubleshooting

- Connector status can be inquired from the hsm-driver container
    - Example: curl http://<IP/host/service>:12345/connector/status
- A successful USB mounting *is essential* when using the Connector as a container layer
    - Make sure the USB is plugged and accessible from the docker host first
- Generating new keys from EJBCA UI is not supported currently
    - Use yubihsm-shell to generate the keys in advance
    - Follow [ECA-10312](https://jira.primekey.se/browse/ECA-10312) for related updates

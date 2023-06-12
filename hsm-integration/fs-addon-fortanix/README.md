![Keyfactor Community](../keyfactor_community_logo.png)

# Adding Fortanix Hardware Security Modules (HSMs) drivers to another file system layer

By taking a release of the EJBCA Community container and adding the PKCS#11 `.so` to the image, you can enable use of the Fortanix HSM driver.

## Adding Fortanix HSM drivers on top of the EJBCA CE container using Docker

The example Containerfile adds a file system layer with the relevant Fortanix HSM driver and configuration on top of the EJBCA CE container. This is an easy way to add and use PKCS#11 drivers that do not require a running daemon in the container.

## Fortanix HSM driver location
The example also shows how to add the driver location, as well as set some other properties, to the list that EJBCA looks for if the driver location is not already known by EJBCA. 
For most HSMs the common driver locations is already known by EJBCA, check conf/web.properties.sample for the locations that EJBCA already searches by default.

## Usage

The example Containerfile adds the Fortanix PKCS#11 drivers and confiugration for the [Fortanix Data Security Manager](https://www.fortanix.com/products/data-security-manager), created by Fortnanix. 


Open a terminal and use the following commands to add the PKCS11 driver to the EJBCA CE container:
```bash
git clone https://github.com/Keyfactor/ejbca-containers.git
cd ejbca-containers/hsm-integration/hsm-drivers/hsm-driver-fortanix
docker build -t ejbca-ce:fortanix -f Containerfile .
```

To run the container use the following command to test with EJBCA CE running ephemerally
```bash
docker run -d --rm --name ejbca-node1 -p 80:8080 -p 443:8443 -h "172.16.170.133" -e FORTANIX_API_ENDPOINT="https://amer.smartkey.io/" -e TLS_SETUP_ENABLED="simple" --memory="1024m" --memory-swap="1024m" --cpus="2" ejbca-ce:fortanix
```

Login to the container, create a crypto token with PKCS11 selecting the Fortanix driver, generate some keys, and then create a certificate profile or use a default one to create a CA.

# EJBCA Docker containers

Enterprise Edition containers of Keyfactor EJBCA applications are made available to customers from a Keyfactor registry. Visit https://www.keyfactor.com/ for more information.

Community Edition containers of Keyfactor EJBCA applications are made available on Dockerhub. See [https://hub.docker.com/r/keyfactor/](https://hub.docker.com/r/keyfactor/ejbca-ce) for a list of currently published applications.

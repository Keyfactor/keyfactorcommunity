![Keyfactor Community](../keyfactor_community_logo.png)

# Adding Hardware Security Modules (HSMs) drivers to another file system layer

By taking a release container and adding the PKCS#11 `.so` to the image, you can enable use of the HSM driver.

## Adding HSM drivers on top of the EJBCA container using docker-compose

The example Dockerfile adds a file system layer with the relevant HSM drivers and configuration on top of the EJBCA container. This is an easy way to add and use PKCS#11 drivers that do not require a running daemon in the container.

## HSM driver location
The example also shows how to add the driver location, as well as set some other properties, to the list that EJBCA looks for if the driver location is not already by default by EJBCA. 
For most HSMs the common driver locations is already known, check conf/web.properties.sample for the locations that EJBCA already searches by default.

## Usage

The example Dockerfile adds PKCS#11 drivers and confiugration for the (FIPS and CC EN 419221-5 certified) [Trident HSM](https://www.i4p.com/), created by I4P. 

The Dockerfile can be modified to add drivers of your choice.

TODO: add command line example how to run docker-compose to build and run the container.

## Adding HSM drivers on top of the EJBCA container using file system mounts

Another way to add relevant HSM drivers, along with their configuration, is by using docker volume mounts.

For example to add a Thales DPoD client (as described in the EJBCA documentation) you can simply mount it and run the container.

Start the container, adding the file system mounts and the environment variable to point to the driver location.
With Enterprise Edition both 'PKCS#11 NG Crypto Token' and 'PKCS#11 Crypto Token' (Java PKCS#11 provider) is available.

```
sudo docker run -it --rm --name thales_test -p 80:8080 -p 443:8443 -v /opt/thales:/opt/thales -e ChrystokiConfigurationPath=/opt/thales/dpodclient registry.primekey.se/primekey/ejbca-ee:latest
```

Or with Community edition, where only 'PKCS#11 Crypto Token' is available.
```
sudo docker run -it --rm --name thales_test -p 80:8080 -p 443:8443 -e TLS_SETUP_ENABLED="simple" -v /opt/thales:/opt/thales -e ChrystokiConfigurationPath=/opt/thales/dpodclient keyfactor/ejbca-ce:latest
```


Manually check that files have been mounted correctly:

```
sudo docker ps
sudo docker exec -ti thales_test /bin/bash
ls -al /opt/thales
```

An example using SoftHSM2 could look like:

```
sudo docker run -it --rm --name softhsm_test -p 80:8080 -p 443:8443 -e TLS_SETUP_ENABLED="simple" -e SOFTHSM2_CONF=/opt/softhsm/config/softhsm2.conf -v /opt/softhsm/lib:/usr/local/lib/softhsm -v /opt/softhsm/tokens:/opt/softhsm/tokens -v /opt/softhsm/config:/opt/softhsm/config -e LOG_LEVEL_APP=DEBUG keyfactor/ejbca-ce:latest
```
We have seen here that privileges on the token is crucial, the container need to have proper access to directories and files or you will get errors like CKR_TOKEN_NOT_RECOGNIZED.

```
sudo docker ps
sudo docker exec -ti softhsm_test /bin/bash
cd /opt/softhsm/tokens
ls -al 81660e6e-fcbf-cdf9-7d37-ae8ac90167b5 (or whatever your token directory is called)
```

# EJBCA Docker containers

Enterprise Edition containers of Keyfactor EJBCA applications are made available to customers from a Keyfactor registry. Visit https://www.keyfactor.com/ for more information.

Community Edition containers of Keyfactor EJBCA applications are made available on Dockerhub. See [https://hub.docker.com/r/keyfactor/](https://hub.docker.com/r/keyfactor/ejbca-ce) for a list of currently published applications.

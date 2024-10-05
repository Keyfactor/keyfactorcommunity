# EJBCA Integration with a SmartCard-HSM

## Overview

The [SmartCard-HSM](https://www.smartcard-hsm.com) is secure element based cryptographic token and key management system.
It supports RSA, ECC and AES keys and through its key domain architecture allows effective control over
cryptographic material in backup or transit. It supports PKCS#11, CSP-Minidriver and Java JCE/JCA.

For integration with EJBCA the PKCS#11 module from the [sc-hsm-embedded](https://github.com/CardContact/sc-hsm-embedded) project is used.
[OpenSC](https://github.com/OpenSC/OpenSC) is available as alternative PKCS#11 module.

The [Dockerfile](Dockerfile) builds the module and amends the keyfactor/ejbca-ce image with /usr/lib64/pkcs11/libsc-hsm-pkcs11.so. Starting with
version 9.1 EJBCA will detect the presence of the module when creating a crypto token.

## Installation

To amend the image with the PKCS#11 module for the SmartCard-HSM you need to run

    docker build -t ejbca-cc .

using the provided [Dockerfile](Dockerfile). Use that image in your docker-compose

````
  ...
  ejbca-node1:
    hostname: ejbca-node1
    container_name: ejbca
#    image: keyfactor/ejbca-ce:latest
#
# Use local build
    image: ejbca-cc:latest
  ...
````

The PKCS#11 module requires access to the PCSC deamon running on the container's host. Therefore the /run/pcscd directory of the host
must be mapped into the container using

````
    volumes:
      - type: bind
        source: /var/run/pcscd
        target: /var/run/pcscd
        read_only: false
````

in the docker-compose file.

## Troubleshooting

If EJBCA does not offer /usr/lib64/pkcs11/libsc-hsm-pkcs11.so as library or accessing the token fails, there are some steps
to validate that the integration is working:

1. Make sure the SmartCard-HSM is working on the host. Use

````
    pkcs11-tool --module /usr/local/lib/libsc-hsm-pkcs11.so -O
````

on the host to list the objects found on the device.

2. Make sure the pcscd socket on the host is available in the running container

````
$ docker exec -it -u root ejbca bash
[root@ejbca-node1 keyfactor]# ls -la /run/pcscd
total 8
drwxr-xr-x 2 root root   80 Oct  3 11:21 .
drwxr-xr-x 1 root root 4096 Oct  4 15:05 ..
srw-rw-rw- 1 root root    0 Oct  3 11:21 pcscd.comm
-rw-r--r-- 1 root root    8 Oct  3 11:21 pcscd.pid
[root@ejbca-node1 keyfactor]#
````

Check the docker-compose file or mounts in the docker command if /run/pcscd is missing.

3. Make sure that p11-kit can enumerate the module

The above build adds a [configuration file](sc-hsm.conf) for the SmartCard-HSM, so that p11-kit can find it:

````
[root@ejbca-node1 keyfactor]# p11-kit list-modules
module: p11-kit-trust
    path: /usr/lib64/pkcs11/p11-kit-trust.so
    uri: pkcs11:library-description=PKCS%2311%20Kit%20Trust%20Module;library-manufacturer=PKCS%2311%20Kit
    library-description: PKCS#11 Kit Trust Module
    library-manufacturer: PKCS#11 Kit
    library-version: 0.25
    token: System Trust
        uri: pkcs11:model=p11-kit-trust;manufacturer=PKCS%2311%20Kit;serial=1;token=System%20Trust
        manufacturer: PKCS#11 Kit
        model: p11-kit-trust
        serial-number: 1
        hardware-version: 0.25
        flags:
              token-initialized
    token: Default Trust
        uri: pkcs11:model=p11-kit-trust;manufacturer=PKCS%2311%20Kit;serial=1;token=Default%20Trust
        manufacturer: PKCS#11 Kit
        model: p11-kit-trust
        serial-number: 1
        hardware-version: 0.25
        flags:
              write-protected
              token-initialized
module: sc-hsm.conf
    path: /usr/lib64/pkcs11/libsc-hsm-pkcs11.so
    uri: pkcs11:library-description=SmartCard-HSM%20via%20PC%2FSC;library-manufacturer=CardContact%20%28www.cardcontact.de%29
    library-description: SmartCard-HSM via PC/SC
    library-manufacturer: CardContact (www.cardcontact.de)
    library-version: 2.12
    token: SmartCard-HSM
        uri: pkcs11:model=SmartCard-HSM;manufacturer=CardContact%20%28www.cardcontact.de%29;token=SmartCard-HSM
        manufacturer: CardContact (www.cardcontact.de)
        model: SmartCard-HSM
        serial-number:
        firmware-version: 3.0
        flags:
              rng
              login-required
              user-pin-initialized
              token-initialized
````

If p11-kit hangs right at the beginning, then probably the installed libpcsclite and the pcscd on the
host are not compatible. This is a [known issue](https://blog.apdu.fr/posts/2022/02/fedora-flatpak-and-pcsc-lite/),
if the host is a Debian based system, while the EJBCA image is based on AlmaLinux.

The workaround is to map the libpcsclite from the host into the container with

````
      - type: bind
        source: /usr/lib/x86_64-linux-gnu/libpcsclite.so.1.0.0
        target: /usr/lib64/libpcsclite.so.1.0.0
        read_only: true
````

4. Make sure ejbcaClientToolBox.sh can access the token

````
[root@ejbca-node1 keyfactor]# ejbcaClientToolBox.sh PKCS11HSMKeyTool test /usr/lib64/pkcs11/libsc-hsm-pkcs11.so 1
2024-10-04 16:04:24,830+0000 INFO  [org.apache.commons.beanutils.FluentPropertyBeanIntrospector] (main) Error when creating PropertyDescriptor for public final void org.apache.commons.configuration2.AbstractConfiguration.setProperty(java.lang.String,java.lang.Object)! Ignoring this property.
Test of keystore with ID 1.
WARNING: An illegal reflective access operation has occurred
WARNING: Illegal reflective access by com.keyfactor.util.keys.token.pkcs11.SunP11SlotListWrapper (file:/opt/keyfactor/ejbca/dist/clientToolBox/lib/cryptotokens-api-1.1.0.jar) to method sun.security.pkcs11.wrapper.PKCS11.getInstance(java.lang.String,java.lang.String,sun.security.pkcs11.wrapper.CK_C_INITIALIZE_ARGS,boolean)
WARNING: Please consider reporting this to the maintainers of com.keyfactor.util.keys.token.pkcs11.SunP11SlotListWrapper
WARNING: Use --illegal-access=warn to enable warnings of further illegal reflective access operations
WARNING: All illegal access operations will be denied in a future release
PKCS11 Token [SunPKCS11-libsc-hsm-pkcs11.so-slot1] Password:

Testing of key: codesigner
Private part:
SunPKCS11-libsc-hsm-pkcs11.so-slot1 RSA private key, 2048 bitstoken object, sensitive, unextractable)
RSA key:
  modulus: e89a9bfb6f2c9023d003cc56259da8f7203bb7b2b51519e3779a3da262df6eb3eb445681ad6caca37329c79beb347b1fd1dd26934768b482e4ab5bf801611cb077c1b3cc9b6370d9166188da76e0cfe9c057115a669a2147438d5e0ceb12e204512b1cda32506e5e1358dc16832b5de9339ff3464eff50334a60115eadd9a6836826cbb1c8ff401ac3fef66f77827f5b378afae767662ee475e2f3a28416801453c2ea4d2749ddc2af0916937d9e1159ac29519975dbafbb3ceb09f7a09646326789dc5fdde951b8391299b82c3fd568dc82f997f3281eac8aac62e4ae9511d3b7fb9fbccf7f63803e13c6347bb8b3c7aba082805bc5d915fa555c055cd87689
  public exponent: 10001
encryption provider: SunJCE version 11; decryption provider: SunPKCS11-libsc-hsm-pkcs11.so-slot1 version 11; modulus length: 2048; byte length 245. The decoded byte string is equal to the original!
2024-10-04 16:04:29,381+0000 INFO  [com.keyfactor.util.keys.SignWithWorkingAlgorithm] (main) Signature algorithm 'SHA1WithRSA' working for provider 'SunPKCS11-libsc-hsm-pkcs11.so-slot1 version 11'.
Signature test of key codesigner: signature length 256; first byte c7; verifying true
Signings per second: 8
Decryptions per second: 8

Testing of key: signKey
Private part:
SunPKCS11-libsc-hsm-pkcs11.so-slot1 RSA private key, 2048 bitstoken object, sensitive, unextractable)
RSA key:
  modulus: 8b8510ec0b44cf32ca18d64c5203a81a55e7fec694cef805fd30f73f9e5d1b18658066eeead32bb3d52696620e5db15d3306b1eb9d2cef7c55265b81789c225b1cbb216e0b8207e776d4c5d095fb7354a4424162916e7b391c1e297661d6a923efc63626b423e8b9beee9e5bbc7e19e74590aaac02b239cec301eae780b9f0b1fbaa6380572e1089000369032c3c8e3bed407cd94a4276cfa332c54d5fc35431b9ad232a27681a4682a833ea3139fd7c1dd6e6711eb782a2c02f59ccc00a495bd4780e366370a2390b5c76a50e89658cd4e8703f3083c9ef5786e29b3c2d327a968a6e82d88f5db018e47819a3e432f44133a0cd2c43cb691f8c085024da7e19
  public exponent: 10001
encryption provider: SunJCE version 11; decryption provider: SunPKCS11-libsc-hsm-pkcs11.so-slot1 version 11; modulus length: 2048; byte length 245. The decoded byte string is equal to the original!
Signature test of key signKey: signature length 256; first byte 55; verifying true
Signings per second: 8
Decryptions per second: 8

Testing of key: signKey2
Private part:
SunPKCS11-libsc-hsm-pkcs11.so-slot1 EC private key, 256 bitstoken object, sensitive, unextractable)
Elliptic curve key:
  Named curve: P-256
  the affine x-coordinate: bbf30dce4ea9e9150f6939b4af29fc989227ad58b3fc51376e6d9aea0c1d964e
  the affine y-coordinate: e094c00d5dd23ac4bef8941bec1059cf21ef9ebe6fcdf46da13e67df57cc32f
2024-10-04 16:04:29,984+0000 INFO  [com.keyfactor.util.keys.SignWithWorkingAlgorithm] (main) Signature algorithm 'SHA256withECDSA' working for provider 'SunPKCS11-libsc-hsm-pkcs11.so-slot1 version 11'.
Signature test of key signKey2: signature length 70; first byte 30; verifying true
Signings per second: 25
No encryption possible with this key.
````

5. If you are using an EJBCA version before 9.1 make sure the libsc-hsm-pkcs11.so module is listed in web.properties

````
[root@ejbca-node1 keyfactor]# cat /opt/keyfactor/ejbca/conf/web.properties
httpserver.pubhttp=80
httpserver.pubhttps=443
httpserver.privhttps=443
httpserver.external.privhttps=443
web.reqcertindb=false

# The CA servers DNS host name, must exist on client using the admin GUI.
httpsserver.hostname=ejbca-node1

cryptotoken.p11.lib.114.file=/usr/lib64/pkcs11/libsc-hsm-pkcs11.so

cryptotoken.p11.lib.255.name=P11 Proxy
cryptotoken.p11.lib.255.file=/opt/keyfactor/p11proxy-client/p11proxy-client.so
cryptotoken.p11.lib.255.canGenerateKeyMsg=ClientToolBox must be used to generate keys for this HSM provider.
 Normally key generation will be allowed via the UI
cryptotoken.p11.lib.255.canGenerateKey=true

# Enable usage of Azure Key Vault Crypto Token in the Admin UI
keyvault.cryptotoken.enabled=true

# Enable usage of AWS KMS Crypto Token in the Admin UI
awskms.cryptotoken.enabled=true

# Enable P11NG for EJBCA to use for CloudHSM and other PKCS11 integrations
p11ng.cryptotoken.enabled=true
web.docbaseuri=disabled
````


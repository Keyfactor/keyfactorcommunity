# Running EJBCA CE on Docker Engine with external database and front-end

This is an example setup an EJBCA installation with an external database and a TLS terminating load-balancing front-end.

The scope of this example is to demonstrate:

* the stateless nature of EJBCA containers in this 3 level setup.
* that EJBCA's shared database model is sufficient for clustering the application.
* demonstrating how the application can by upgraded without service down time.

A highly available service in production would additionally use

* EJBCA EE with 24/7 support by PrimeKey
* redundant highly available hardened and optimized load-balancers
* a redundant highly available hardened and optimized database like MariaDB Galera cluster.

Setting up redundant load-balancers, spanning the network over multiple host and clustering the database is out of scope for this particular example.

## Prerequisites

For this example you will need an existing Management CA that has issued a TLS certificate for the front end:


```
  pem/mycahostname-CA.pem
  pem/mycahostname.pem
  pem/mycahostname-Key.pem
```

and a `superadmin.p12` client certificate key store with "CN=SuperAdmin" issued from the same Management CA.

It is also assumed that you have a functional Docker Engine installation.


## Setup


### Create a private network bridge

The private bridge will be used for container-to-container communication. Select a sub-net that is not already in use or used by other local services.

```
docker network create --driver bridge --subnet 172.28.0.0/16 ejbca-bridge
```

### Setup a database back-end

The following will run a stand-alone instance of MariaDB as back-end.

```
docker run -d --restart=always --network ejbca-bridge --name ejbca-database \
    -e MYSQL_ROOT_PASSWORD=foo123 \
    -e MYSQL_DATABASE=ejbca \
    -e MYSQL_USER=ejbca \
    -e MYSQL_PASSWORD=ejbca \
    library/mariadb --character-set-server=utf8 --collation-server=utf8_bin
```

### Start the first EJBCA node

Start the first instance only exposing an AJP connector on the private network bridge.

```
docker run -d --restart=always --network ejbca-bridge --name ejbca-node1 \
    -e "DATABASE_JDBC_URL=jdbc:mysql://ejbca-database:3306/ejbca?characterEncoding=UTF-8" \
    -e "DATABASE_USER=ejbca" \
    -e "DATABASE_PASSWORD=ejbca" \
    -e "PROXY_AJP_BIND=0.0.0.0" \
    primekey/ejbca-ce
```

Follow the progress by tailing the logs:
```
docker logs -f ejbca-node1
```

#### Configure EJBCA management to use a client TLS certificate

Although this is an optional step for air-gapped testing, it is strongly recommended.

By default anyone with network access to the instance will have full management rights when we run it in proxy mode.
Since we want to manage this with a TLS client certificate instead we remove this "admin".
```
docker exec -it ejbca-node1 ejbca.sh roles removeadmin \
    --role 'Super Administrator Role' \
    --caname "" \
    --with PublicAccessAuthenticationToken:TRANSPORT_CONFIDENTIAL \
    --value ""
```

We then import the issuer of the client TLS certificate and add a rule to treat the certificate with `CN=SuperAdmin` as part of the `Super Administrator Role`.  
```
docker cp pem/mycahostname-CA.pem ejbca-node1:/tmp/ca.pem
docker exec -it ejbca-node1 ejbca.sh ca importcacert \
    --caname "ManagementCA" -f "/tmp/ca.pem" \
    -initauthorization -superadmincn SuperAdmin
```

### Setup an Apache httpd front-end

Ensure that you have a local copy of [httpd.conf](httpd.conf) and the corresponding PEM encoded certificates and key in the `pem/` directory for this step.  

```
docker run -d --network ejbca-bridge --name ejbca-frontend --hostname mycahostname \
    -p 80:80 -p 443:443 \
    -v $(pwd)/httpd.conf:/usr/local/apache2/conf/httpd.conf \
    -v $(pwd)/pem:/etc/httpd/ssl \
    library/httpd:2.4
```

Once the front-end is running and has performed health-checks of it's application backends, you should be able to accesss EJBCA using `http://mycahostname:80/ejbca/` and manage the instance by logging in with your client certificate at `https://mycahostname:443/ejbca/adminweb/`.

### Start an additional EJBCA node

```
docker run -d --restart=always --network ejbca-bridge --name ejbca-node2 \
    -e "DATABASE_JDBC_URL=jdbc:mysql://ejbca-database:3306/ejbca?characterEncoding=UTF-8" \
    -e "DATABASE_USER=ejbca" \
    -e "DATABASE_PASSWORD=ejbca" \
    -e "PROXY_AJP_BIND=0.0.0.0" \
    primekey/ejbca-ce
```

The front end will automatically add this back-end once it is started.


## Rolling application upgrade

Since all relevant information is stored in the shared SQL database, we simply need to remove the replace the running instances with new ones.

Download new image:
```
docker pull primekey/ejbca-ce
```

Replace `ejbca-node1`:
```
docker rm -f ejbca-node1
docker run -d --restart=always --network ejbca-bridge --name ejbca-node1 \
    -e "DATABASE_JDBC_URL=jdbc:mysql://ejbca-database:3306/ejbca?characterEncoding=UTF-8" \
    -e "DATABASE_USER=ejbca" \
    -e "DATABASE_PASSWORD=ejbca" \
    -e "PROXY_AJP_BIND=0.0.0.0" \
    primekey/ejbca-ce
```

Verify that `ejbca-node1` started successfully:
```
docker logs -f ejbca-node1
```

Replace `ejbca-node2`, once `ejbca-node1` has started:
```
docker rm -f ejbca-node2
docker run -d --restart=always --network ejbca-bridge --name ejbca-node2 \
    -e "DATABASE_JDBC_URL=jdbc:mysql://ejbca-database:3306/ejbca?characterEncoding=UTF-8" \
    -e "DATABASE_USER=ejbca" \
    -e "DATABASE_PASSWORD=ejbca" \
    -e "PROXY_AJP_BIND=0.0.0.0" \
    primekey/ejbca-ce
```

Verify that `ejbca-node2` started successfully:
```
docker logs -f ejbca-node2
```

Done!

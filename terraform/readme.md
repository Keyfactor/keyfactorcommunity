# RUNNING EJBCA DOCKER WITH TERRAFORM
Run a production-ready [EJBCA docker container][1] using Terraform using an external MariaDB database and a Nginx reverse proxy.
Environment variables:
- `TLS_SETUP_ENABLED=later`
- `PROXY_HTTP_BIND`

## PREREQUISITES
For this example you will need:
- [Nginx](http://nginx.org/) reverse proxy as a front-end
- External [MariaDB](https://mariadb.com/) database
- [Terraform](https://developer.hashicorp.com/terraform/install)

Other deployement scenario are covered elsewhere:
- [Using docker database](https://docs.keyfactor.com/ejbca/latest/tutorial-start-out-with-ejbca-docker-container) with compose
- [Using httpd proxy](https://github.com/Keyfactor/keyfactorcommunity/tree/main/deployment-examples/docker-engine/ejbca-ce-three-level-architecture)

## SETUP 
```
git clone https://github.com/Keyfactor/keyfactorcommunity.git
cd keyfactorcommunity/deployement-examples/terraform
```

Copy the nginx configuration file:
```
cp mysite /etc/sites-available
ln -s /etc/sites-available/mysite /etc/sites-enabled
nginx -s reload
```

Setup your own terraform variable:
```
cp example.tfvars.sample production.tfvars
```

Deploy 🚀:
```
terraform init .
terraform apply -var-file production.tfvars
```

---

[1]: https://hub.docker.com/r/keyfactor/ejbca-ce

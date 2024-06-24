terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
    }
  }
}

provider "docker" {
  host     = "ssh://${var.ssh_user}@${var.remote_host}:${var.ssh_port}"
  ssh_opts = ["-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null"]
}


resource "docker_image" "ejbca_img" {
  name         = var.image_name
  keep_locally = true
}

resource "docker_network" "ejbca_net" {
  name            = "ejbca_net"
  attachable      = false
  check_duplicate = true
  ipam_config {
    subnet = var.network_subnet
  }
}

resource "docker_container" "ejbca" {
  name  = var.container_name
  image = docker_image.ejbca_img.name
  env = [
    "DATABASE_JDBC_URL=jdbc:mariadb://${var.db_host}:3306/${var.db_name}?characterEncoding=UTF-8",
    "DATABASE_USER=ejbca",
    "DATABASE_PASSWORD=${var.db_password}",
    "LOG_LEVEL_APP=INFO",
    "LOG_LEVEL_SERVER=INFO",
    "TLS_SETUP_ENABLED=later",
    "PASSWORD_ENCRYPTION_KEY=changeme",
    "CA_KEYSTOREPASS=changeme",
    "EJBCA_CLI_DEFAULTPASSWORD=ejbca",
    "PROXY_HTTP_BIND=${var.container_ip}",
  ]
  memory = 2000
  networks_advanced {
    name         = docker_network.ejbca_net.name
    ipv4_address = var.container_ip
  }
}

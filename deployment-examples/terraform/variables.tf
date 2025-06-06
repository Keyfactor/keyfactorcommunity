variable "ssh_user" {
  description = "Remote host"
  type        = string
  sensitive   = true
}

variable "ssh_port" {
  description = "Remote host"
  type        = string
  sensitive   = true
}

variable "remote_host" {
  description = "Remote host"
  type        = string
  sensitive   = true
}

variable "db_host" {
  description = "Host of the database"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Name of the database"
  type        = string
  default     = "ejbca"
}

variable "db_password" {
  description = "Password of the database"
  type        = string
  sensitive   = true
}

variable "image_name" {
  description = "Name of the ejbca image"
  type        = string
  default     = "keyfactor/ejbca-ce"
}

variable "container_name" {
  description = "Name of the container"
  type        = string
  default     = "ejbca"
}


variable "network_subnet" {
  description = "CIDR format of the network subnet"
  type        = string
  default     = "172.3.0.0/16"
}

variable "container_ip" {
  description = "Local IP address of the container"
  type        = string
  default     = "172.3.0.5"
}

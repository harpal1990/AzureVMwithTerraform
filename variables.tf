variable "node_location" {
  type = string
}

variable "resource_prefix" {
  type = string
}

variable "node_address_space" {
  default = ["10.0.0.0/16"]
}

#variable for network range

variable "node_address_prefix" {
  default = "10.0.0.0/24"
}

#variable for Environment
variable "Environment" {
  type = string
}

variable "node_count" {
  type = number
}
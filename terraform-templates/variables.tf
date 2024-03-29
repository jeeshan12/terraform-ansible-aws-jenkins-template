variable "profile" {
  type    = string
  default = "default"
}

variable "region-master" {
  type    = string
  default = "us-east-1"
}


variable "region-master" {
  type    = string
  default = "us-east-1"
}

variable "region-worker" {
  type    = string
  default = "us-east-1"
}

variable "subet-1-worker" {
  type    = string
  default = "192.168.0.0/24"
}

variable "subet-1-master" {
  type    = string
  default = "10.0.1.0/24"
}

variable "subet-2-master" {
  type    = string
  default = "10.0.2.0/24"
}

variable "external_ip" {
  type    = string
  default = "0.0.0.0/0"
}

variable "all_traffic" {
  type    = string
  default = "0.0.0.0/0"
}



variable "instance-type" {
  type    = string
  default = "t3.micro"
}


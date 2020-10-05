variable "name" {
  default = "screencap"
}

variable "tags" {
  type = map(string)
  default = {}
}

variable "certificate_arn" {
  default = ""
}
variable "domain_name" {
  default = ""
}

variable "lambda_role" {
  default = ""
}

variable "keys" {
  type = set(string)
  default = ["canvas"]
}
variable "region" {
  description = "Region AWS (seule region du Learner Lab)"
  type        = string
  default     = "us-east-1"
}

variable "projet" {
  description = "Prefixe des noms de ressources"
  type        = string
  default     = "securecloud-pme"
}

variable "vpc_cidr" {
  description = "Plage d'adresses du VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "zones" {
  description = "Les 2 zones de disponibilite"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "enable_nat" {
  description = "Creer la NAT Gateway (payante) : false au debut, true a l'etape 8"
  type        = bool
  default     = false
}
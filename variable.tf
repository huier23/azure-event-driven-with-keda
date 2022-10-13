variable "location" {
  default = "East Asia" 
}

variable "RGName" {
  default = "dumpfile"      
}


variable "storage" {
  default = "stgtmdumpfile"
}

variable "container" {
  default = "dump"
}

variable "sbus1" {
  default = "sbus-upload"
}

variable "sbusXL" {
  default = "sbus-XL"
}

variable "sbusL" {
  default = "sbus-L"
}

variable "sbusM" {
  default = "sbus-M"
}

variable "eventgrid" {
  default = "evgrid-dumpupload"
}

variable "funcplan" {
  default = "planfunctionapp"
}

variable "funcapp" {
  default = "funcdumpfile"
}

variable appConf {
    default = "appconfdump"

}

variable keyvault {
  default = "keyvaultdump"
}

variable "virtualnet" {
  default = "vnet-dump"
}

variable "vnet-subnet" {
  default = "Subnet-AKS7"
}

variable log_analytics_workspace_name {
    default = "Log-AKS"
}

# refer https://azure.microsoft.com/pricing/details/monitor/ for log analytics pricing 
variable log_analytics_workspace_sku {
    default = "PerGB2018"

}

variable "aks" {
  default = "aks-dump"
}

variable "profile_windone_name" {
  default = "azureuser"
}

variable "profile_windone_passwork" {
  default = "IloveAzure@2021"
}


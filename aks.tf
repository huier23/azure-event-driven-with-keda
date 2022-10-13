# Create VNet
resource "azurerm_virtual_network" "virtualnetwork" {
  name                = var.virtualnet
  location            = var.location
  resource_group_name = var.RGName
  address_space       = ["10.0.0.0/21"]
  depends_on      = [ azurerm_resource_group.DumpFile ]
}

resource "azurerm_subnet" "aks-subnet" {
  name           = var.vnet-subnet
  virtual_network_name = azurerm_virtual_network.virtualnetwork.name
  resource_group_name = var.RGName
  address_prefixes = ["10.0.1.0/24"]
  depends_on      = [ azurerm_resource_group.DumpFile ]
}

output "aks_subnet_id" {
  value = azurerm_subnet.aks-subnet.id
}

# Create Log-Analytics

resource "azurerm_log_analytics_workspace" "aksloganalytics" {
  name                = var.log_analytics_workspace_name
  location            = var.location
  resource_group_name = var.RGName
  sku                 = "PerGB2018"
  retention_in_days   = 30
  depends_on      = [ azurerm_resource_group.DumpFile ] 
}

resource "azurerm_log_analytics_solution" "containerinsghts" {
    solution_name         = "ContainerInsights"
    location              = var.location
    resource_group_name   = var.RGName
    workspace_resource_id = azurerm_log_analytics_workspace.aksloganalytics.id
    workspace_name        = azurerm_log_analytics_workspace.aksloganalytics.name

    plan {
        publisher = "Microsoft"
        product   = "OMSGallery/ContainerInsights"
    }
    depends_on      = [ azurerm_resource_group.DumpFile ]
}

# Create AKS
# Ebable AAD IAM & K8S Role
# Change to Fsv2 
resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.aks
  location            = var.location
  resource_group_name = var.RGName
  dns_prefix          = var.aks
  //automatic_channel_upgrade = "none"
  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_D2_v2"
    vnet_subnet_id = azurerm_subnet.aks-subnet.id
  }
  
  addon_profile {
        oms_agent {
        enabled                    = true
        log_analytics_workspace_id = azurerm_log_analytics_workspace.aksloganalytics.id
        }
    }

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
    service_cidr = "10.0.4.0/24"
    dns_service_ip = "10.0.4.10"
    docker_bridge_cidr = "172.17.0.1/16"
  }

  identity {
    type = "SystemAssigned"
  }
  
  windows_profile {
    admin_username = var.profile_windone_name
    admin_password = var.profile_windone_passwork
  }
  depends_on      = [ azurerm_resource_group.DumpFile ]
}

# output "host" {
#   value = azurerm_kubernetes_cluster.aks.kube_config.0.host
# }

# output "cluster_ca_certificate" {
#   value = azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate
# }

# output "client_key" {
#   value = azurerm_kubernetes_cluster.aks.kube_config.0.client_key
# }

# output "client_certificate" {
#   value = azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate
# }

# output "kube_config" {
#   value = azurerm_kubernetes_cluster.aks.kube_config_raw
   
#   # change to show  
#   sensitive = true
# }

provider "kubernetes"{
  host                   = azurerm_kubernetes_cluster.aks.kube_config.0.host
  username               = azurerm_kubernetes_cluster.aks.kube_config.0.username
  password               = azurerm_kubernetes_cluster.aks.kube_config.0.password
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate)
}

# Create namespace
resource "kubernetes_namespace" "aks-namespace" {
  metadata {
    name = "keda"
  }
  depends_on = [azurerm_kubernetes_cluster.aks]
}

resource "kubernetes_namespace" "aks-namespace-mqueue" {
  metadata {
    name = "scaled-m-queue"
  }
  depends_on = [azurerm_kubernetes_cluster.aks]
}

resource "kubernetes_namespace" "aks-namespace-lqueue" {
  metadata {
    name = "scaled-l-queue"
  }
  depends_on = [azurerm_kubernetes_cluster.aks]
}

resource "kubernetes_namespace" "aks-namespace-xlqueue" {
  metadata {
    name = "scaled-xl-queue"
  }
  depends_on = [azurerm_kubernetes_cluster.aks]
}

# Helm install keda
provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.aks.kube_config.0.host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate)

  }
}

resource "helm_release" "keda" {
  name = "keda"
  namespace = "keda"
  repository = "https://kedacore.github.io/charts"
  chart      = "keda"
  
  depends_on = [azurerm_kubernetes_cluster.aks]
}

# Create Windows Node Pool

resource "azurerm_kubernetes_cluster_node_pool" "win-m" {
  name                  = "winm"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  # /change to Fsv2 SKU
  vm_size               = "Standard_D4S_v4" 
  availability_zones    = []
  vnet_subnet_id        = azurerm_subnet.aks-subnet.id
  os_type               = "Windows"
  node_count            = 1
  max_pods              = 100
  os_disk_size_gb       = 128
  enable_auto_scaling   = true
  enable_host_encryption= false
  enable_node_public_ip = false
  fips_enabled          = false
  node_taints           = []
  max_count = 10
  min_count = 1
  tags = {
    Environment = "Production"
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "win-l" {
  name                  = "winl"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  # /change to Fsv2 SKU
  vm_size               = "Standard_D4S_v4" 
  availability_zones    = []
  vnet_subnet_id        = azurerm_subnet.aks-subnet.id
  os_type               = "Windows"
  node_count            = 1
  max_pods              = 100
  os_disk_size_gb       = 128
  enable_auto_scaling   = true
  enable_host_encryption= false
  enable_node_public_ip = false
  fips_enabled          = false
  node_taints           = []
  max_count = 10
  min_count = 1
  tags = {
    Environment = "Production"
  }
}

# resource "azurerm_kubernetes_cluster_node_pool" "win-xl" {
#   name                  = "winxl"
#   kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
#   # /change to Fsv2 SKU
#   vm_size               = "Standard_D4S_v4" 
#   os_type               = "Windows"
#   node_count            = 1
#   max_pods              = 100
#   os_disk_size_gb       = 128
#   enable_auto_scaling   = true
  # max_count = 10
  # min_count = 1  
#   tags = {
#     Environment = "Production"
#   }
# }
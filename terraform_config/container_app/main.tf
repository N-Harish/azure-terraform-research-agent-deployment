data "azurerm_client_config" "current" {}

variable "image_tag" {
    type = string
    default = "latest"
}

resource "azurerm_resource_group" "research-agent-resource-group" {
    name = "research-agent-resource-group"
    location = "uksouth"
}

resource "azurerm_user_assigned_identity" "research-agent-user-assigned-identity" {
    name = "research-agent-user-assigned-identity"
    resource_group_name = azurerm_resource_group.research-agent-resource-group.name
    location = azurerm_resource_group.research-agent-resource-group.location
    depends_on = [
        azurerm_resource_group.research-agent-resource-group
    ]
}

resource "azurerm_key_vault" "research-agent-key-vault" {
    name = "research-agent-key-vault"
    resource_group_name = azurerm_resource_group.research-agent-resource-group.name
    location = azurerm_resource_group.research-agent-resource-group.location
    tenant_id = data.azurerm_client_config.current.tenant_id
    sku_name = "standard"
    purge_protection_enabled = false
    soft_delete_retention_days = 7
    access_policy {
        tenant_id = data.azurerm_client_config.current.tenant_id
        object_id = data.azurerm_client_config.current.object_id

        # need to give delete and purge permission for deleting the key-vault using terraform
        secret_permissions = ["Get", "Set", "List", "Delete", "Purge"]
        key_permissions = ["Create","Get", "List", "Delete", "Purge"]
    }
    depends_on = [
        azurerm_resource_group.research-agent-resource-group
    ]
}

# assign access policy to the user assigned identity for getting secrets from the key vault
resource "azurerm_key_vault_access_policy" "key_vault_user_role_assignment" {
    key_vault_id = azurerm_key_vault.research-agent-key-vault.id
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azurerm_user_assigned_identity.research-agent-user-assigned-identity.principal_id
    secret_permissions = ["Get", "List"]
    key_permissions = ["Get", "List"]
    depends_on = [
        azurerm_user_assigned_identity.research-agent-user-assigned-identity,
        azurerm_key_vault.research-agent-key-vault
    ]
}

# create a container app environment
resource "azurerm_container_app_environment" "research-agent-container-app-environment" {
    name = "research-agent-container-app-environment"
    resource_group_name = azurerm_resource_group.research-agent-resource-group.name
    location = azurerm_resource_group.research-agent-resource-group.location
    depends_on = [
        azurerm_resource_group.research-agent-resource-group
    ]
}

# create a log analytics workspace
resource "azurerm_log_analytics_workspace" "research-agent-log-analytics-workspace" {
    name = "research-agent-log-analytics-workspace"
    resource_group_name = azurerm_resource_group.research-agent-resource-group.name
    location = azurerm_resource_group.research-agent-resource-group.location
    depends_on = [
        azurerm_resource_group.research-agent-resource-group
    ]
}

# create a container registry
resource "azurerm_container_registry" "research-agent-container-registry" {
    name = "ResearchAgentContainerRegistry"
    resource_group_name = azurerm_resource_group.research-agent-resource-group.name
    location = azurerm_resource_group.research-agent-resource-group.location
    sku = "Basic"
    admin_enabled = true
    depends_on = [
        azurerm_resource_group.research-agent-resource-group
    ]
}

# assign pull request role to the user assigned identity
resource "azurerm_role_assignment" "research-agent-container-registry-role-assignment" {
    scope = azurerm_container_registry.research-agent-container-registry.id
    role_definition_name = "AcrPull"
    principal_id = azurerm_user_assigned_identity.research-agent-user-assigned-identity.principal_id
    depends_on = [
        azurerm_user_assigned_identity.research-agent-user-assigned-identity, 
        azurerm_container_registry.research-agent-container-registry
    ]
}

# build the image using docker
resource "docker_image" "research-agent-image" {
  name = "${azurerm_container_registry.research-agent-container-registry.login_server}/research-agent/research-agent:${var.image_tag}"
  build {
    context    = "../../app"
    dockerfile = "../../app/Dockerfile"
  }
  depends_on = [
    azurerm_container_registry.research-agent-container-registry
  ]
}

# push the image to the container registry
resource "docker_registry_image" "research-agent-image-push" {
    auth_config {
        address = azurerm_container_registry.research-agent-container-registry.login_server
        username = azurerm_container_registry.research-agent-container-registry.admin_username
        password = azurerm_container_registry.research-agent-container-registry.admin_password
    }
    name = docker_image.research-agent-image.name
    depends_on = [docker_image.research-agent-image]
}


# create a container app
resource "azurerm_container_app" "research-agent-container-app" {
    name = "research-agent-container-app"
    resource_group_name = azurerm_resource_group.research-agent-resource-group.name
    container_app_environment_id = azurerm_container_app_environment.research-agent-container-app-environment.id
    revision_mode = "Single"
    
    # add User Managed Identity to the container app
    identity {
        type = "UserAssigned"
        identity_ids = [azurerm_user_assigned_identity.research-agent-user-assigned-identity.id]
    }

    # use the user assigned identity to pull the image from the container registry
    registry {
        server = azurerm_container_registry.research-agent-container-registry.login_server
        identity = azurerm_user_assigned_identity.research-agent-user-assigned-identity.id
    }
    
    # add secrets to the container app
    secret {
        name = "tavily-api-key"
        identity = azurerm_user_assigned_identity.research-agent-user-assigned-identity.id
        key_vault_secret_id = azurerm_key_vault_secret.research-agent-kv-secrets-tavily-api-key.id
    }
    secret {
        name = "groq-api-key"
        identity = azurerm_user_assigned_identity.research-agent-user-assigned-identity.id
        key_vault_secret_id = azurerm_key_vault_secret.research-agent-kv-secrets-groq-api-key.id
    }

    # add template to the container app
    template {
        min_replicas = 1
        max_replicas = 1
        
        container {
            cpu = 0.5
            memory = "1.0Gi"
            name = "research-agent-container"
            # image = docker_registry_image.research-agent-image-push.image_id
            image = docker_image.research-agent-image.name

            # add environment variables to the container app
            env {
                name = "TAVILY_API_KEY"
                secret_name = "tavily-api-key"
            }
            env {
                name = "GROQ_API_KEY"
                secret_name = "groq-api-key"
            }
        }
    }

    # ingress settings
    ingress {
        target_port = 8051
        external_enabled = true
        traffic_weight {
            latest_revision = true
            percentage = 100
        }
    }
    # depends on container registry, container registry role assignment, key vault, key vault access policy, container app environment, log analytics workspace, image push, key vault secrets
    depends_on = [
        azurerm_role_assignment.research-agent-container-registry-role-assignment,
        azurerm_key_vault_access_policy.key_vault_user_role_assignment,
        azurerm_container_app_environment.research-agent-container-app-environment, 
        azurerm_log_analytics_workspace.research-agent-log-analytics-workspace, 
        docker_registry_image.research-agent-image-push, 
        azurerm_key_vault_secret.research-agent-kv-secrets-tavily-api-key,
        azurerm_key_vault_secret.research-agent-kv-secrets-groq-api-key
    ]
}

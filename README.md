# Azure Terraform Research Agent Deployment

* Research Agent is an Agentic App conssiting of two agents. One agent acts as a searcher (Uses tool to gather top 15 articles for the topic that user is asking about and the other agent acts as a content writer, it takes the search results returned by the researcher agent and then writes an article along with citations.
* All the code alnong with the requirements is in the ```app``` folder
* To reduce size of the docker image, we have used multi-stage build ( refer [Docker File](./app/Dockerfile) here) 
* To run the agent locally, refer [Local Set Up](./app/README.md)

# pre-requisites for deploying using terraform
* make sure ```docker``` is installed and working
* ```azure cli``` should be installed 
* ```terraform``` should be installed and configured to work with Azure by creating Service Principal and setting required environment variables (refer [official terraform azure provider page](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/service_principal_client_secret#creating-a-service-principal-using-the-azure-cli)). 

# Terraform configs for deployment on Azure Container App 

## Architecture Diagram:
![research-agent-arch (1)](https://github.com/user-attachments/assets/620b4ced-50d4-4acf-b731-0a3525a4c212)

## Terraform Code Explained
 
* ```provider.tf``` :- setting up the required providers (```azurerm (stands for Azure Resource Manager) and docker provider```)
  
  ```terraform
  terraform {
    required_version = ">=1.0"
    required_providers {
      azurerm = {
        source  = "hashicorp/azurerm"
        version = "4.1.0"
      }
      docker = {
        source  = "kreuzwerker/docker"
        version = "3.5.0"
      }
    }
  }
  
  provider "azurerm" {
    features {}
  }
  
  
  provider "docker" {
    
  }
  ```

* ```main.tf``` :- main terraform config file for creating all the resorces
  
  - create resource group and setup an User Managed Assigned Identity (UMAI)
    ```terraform
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
    ```
  - creating key vault and set access policy for getting secrets to the UMAI (we need to assign purge and delete permission to keyvault so that we can destroy the infra latter
    ```terraform
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
    ```
  - creaate container registry, assign ArcPull permission to UMAI, use docker provider to build and push image to container registry
     ```terraform
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
```

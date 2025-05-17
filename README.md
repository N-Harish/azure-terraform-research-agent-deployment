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

## To setup this infrastructure
* cd into ```terraform_config/container_app```
* run
  ```
  terraform init
  ```
  command
* next, run
  ```
  terraform plan -out main.tfplan
  ```
* Finally, run
  ```
  terraform apply main.tfplan
  ```
* To destroy the complete infra, run
  ```
  terraform destroy
  ```

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
---
* ```kvsecrets.tf``` :- has block to set secrets in the key vault. (Note:- replace ```<YOU_TAVILY_API_KEY>``` and ```<YOU_GROQ_API_KEY>``` with your keys respectively. (How to get these keys are mentioned [here](./app/README.md)). Secrets will only be set after keyvault is created which will be done in ```main.tf```
   ```terraform
   # set secrets in the key vault
   resource "azurerm_key_vault_secret" "research-agent-kv-secrets-tavily-api-key" {
       name = "tavily-api-key"
       value = "<YOUR_TAVILY_API_KEY>"
       key_vault_id = azurerm_key_vault.research-agent-key-vault.id
       depends_on = [
           azurerm_key_vault_access_policy.key_vault_user_role_assignment
       ]
   }
   
   resource "azurerm_key_vault_secret" "research-agent-kv-secrets-groq-api-key" {
       name = "groq-api-key"
       value = "<YOUR_GROQ_API_KEY>"
       key_vault_id = azurerm_key_vault.research-agent-key-vault.id
       depends_on = [
           azurerm_key_vault_access_policy.key_vault_user_role_assignment
       ]
   }
   ```
---
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
  - create container environment for runtime and log analytics workspace for logging since container app needs both of these for running
    ```terraform
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
    ```
  - create container app and assign it the UMAI for accesing image from container registry and setting container secrets from key vault. Also enable external access as this is a web app
    ```terraform
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
    ```
    



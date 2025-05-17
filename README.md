# Azure Terraform Research Agent Deployment

* Research Agent is an Agentic App conssiting of two agents. One agent acts as a searcher (Uses tool to gather top 15 articles for the topic that user is asking about and the other agent acts as a content writer, it takes the search results returned by the researcher agent and then writes an article along with citations.
* All the code alnong with the requirements is in the ```app``` folder
* To reduce size of the docker image, we have used multi-stage build ( refer [Docker File](./app/Dockerfile) here) 
* To run the agent locally, refer [Local Set Up](./app/README.md)

## pre-requisites for deploying using terraform
* make sure ```docker``` is installed and working
* ```azure cli``` should be installed 
* ```terraform``` should be installed and configured to work with Azure by creating Service Principal and setting required environment variables (refer [official terraform azure provider page](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/service_principal_client_secret#creating-a-service-principal-using-the-azure-cli)). 

## Terraform configs for deployment on Azure Container App 

### Architecture Diagram:
![research-agent-arch (1)](https://github.com/user-attachments/assets/620b4ced-50d4-4acf-b731-0a3525a4c212)

### Terraform Code Explained

#### provider.tf
setting up the required providers (```azurerm (stands for Azure Resource Manager) and docker provider```)

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

####

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
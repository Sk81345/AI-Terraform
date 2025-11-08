param (
    [string]$Prompt
)

# === Variables ===
$OpenAIEndpoint = $env:AZURE_OPENAI_ENDPOINT
$OpenAIKey      = $env:AZURE_OPENAI_KEY
$Model          = "gpt-4o"

Write-Host "🧠 Generating Terraform for prompt: $Prompt"

# === Call Azure OpenAI ===
$Body = @{
    messages = @(
        @{ role = "system"; content = "You are a Terraform expert. Generate Azure VM code with RG, VNet, NSG, Public IP, and Ubuntu VM." }
        @{ role = "user"; content  = "Generate Terraform code for: $Prompt" }
    )
    max_tokens = 1500
} | ConvertTo-Json -Depth 5

$Headers = @{
    "api-key" = $OpenAIKey
    "Content-Type" = "application/json"
}

$Response = Invoke-RestMethod -Uri "$OpenAIEndpoint/openai/deployments/$Model/chat/completions?api-version=2024-02-15-preview" -Method POST -Headers $Headers -Body $Body

$TfCode = $Response.choices[0].message.content
Set-Content -Path "main.tf" -Value $TfCode

Write-Host "✅ Terraform file created."

terraform init
terraform apply -auto-approve

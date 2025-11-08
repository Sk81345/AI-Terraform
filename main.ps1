param (
    [string]$Prompt
)

# === Variables ===
$OpenAIEndpoint = $env:AZURE_OPENAI_ENDPOINT.TrimEnd('/')
$OpenAIKey      = $env:AZURE_OPENAI_KEY
$DeploymentName = "gpt4o-deploy"  # 👈 must match your actual deployment name
$ApiVersion     = "2024-02-15-preview"

Write-Host "🧠 Generating Terraform for prompt: $Prompt"

# === Prepare request ===
$Body = @{
    messages = @(
        @{ role = "system"; content = "You are a Terraform expert. Generate Azure VM code with RG, VNet, NSG, Public IP, and Ubuntu VM." }
        @{ role = "user";   content = "Generate Terraform code for: $Prompt" }
    )
    max_tokens = 1500
} | ConvertTo-Json -Depth 5

$Headers = @{
    "api-key" = $OpenAIKey
    "Content-Type" = "application/json"
}

# === Call Azure OpenAI ===
$Uri = "$OpenAIEndpoint/openai/deployments/$DeploymentName/chat/completions?api-version=$ApiVersion"

Write-Host "📡 Calling deployment at: $Uri"

try {
    $Response = Invoke-RestMethod -Uri $Uri -Method POST -Headers $Headers -Body $Body -ErrorAction Stop
    $TfCode = $Response.choices[0].message.content
    Set-Content -Path "main.tf" -Value $TfCode
    Write-Host "✅ Terraform file created."
} 
catch {
    Write-Host "❌ Failed to call Azure OpenAI deployment: $($_.Exception.Message)"
    throw
}

# === Run Terraform ===
terraform init
terraform apply -auto-approve

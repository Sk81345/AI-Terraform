param (
    [string]$Prompt
)

# === Variables ===
$OpenAIEndpoint = $env:AZURE_OPENAI_ENDPOINT.TrimEnd('/')
$OpenAIKey      = $env:AZURE_OPENAI_KEY
$DeploymentName = "gpt4o-deploy"      # must match your Azure deployment name
$ApiVersion     = "2024-02-15-preview"

Write-Host "🧠 Generating Terraform for prompt: $Prompt"

# === Prepare request for Azure OpenAI ===
$Body = @{
    messages = @(
        @{
            role    = "system"
            content = @"
You are a Terraform expert.
Return ONLY valid Terraform HCL code — no explanations, no markdown, no backticks.
Start directly with 'terraform {' or 'resource "'.
"@
        },
        @{
            role    = "user"
            content = "Generate Terraform to create: $Prompt including Resource Group, Virtual Network, Subnet, NSG, Public IP, and Ubuntu VM."
        }
    )
    max_tokens = 1500
} | ConvertTo-Json -Depth 5

$Headers = @{
    "api-key"      = $OpenAIKey
    "Content-Type" = "application/json"
}

# === Call Azure OpenAI ===
$Uri = "$OpenAIEndpoint/openai/deployments/$DeploymentName/chat/completions?api-version=$ApiVersion"
Write-Host "📡 Calling deployment at: $Uri"

try {
    $Response = Invoke-RestMethod -Uri $Uri -Method POST -Headers $Headers -Body $Body -ErrorAction Stop
    $TfCode = $Response.choices[0].message.content

    # Remove markdown / extra text if any
    $TfCode = $TfCode -replace '```hcl', ''
    $TfCode = $TfCode -replace '```', ''
    $TfCode = $TfCode -replace 'Below.*', ''

    # Keep only lines that start with Terraform keywords
    $TfCode = ($TfCode -split "`n" | Where-Object { $_ -match '^(terraform|provider|resource|variable|output)' }) -join "`n"

    # Write Terraform file
    Set-Content -Path "main.tf" -Value $TfCode -Encoding UTF8
    Write-Host "✅ Terraform code generated and cleaned successfully."
}
catch {
    Write-Host "❌ Failed to call Azure OpenAI deployment: $($_.Exception.Message)"
    throw
}

# === Run Terraform ===
terraform init
terraform validate
terraform apply -auto-approve

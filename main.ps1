param (
    [string]$Prompt = "Create Ubuntu VM in EastUS named NextOpsLVM07"
)

$OpenAIEndpoint = $env:AZURE_OPENAI_ENDPOINT.TrimEnd('/')
$OpenAIKey      = $env:AZURE_OPENAI_KEY
$DeploymentName = "gpt4o-deploy"
$ApiVersion     = "2024-02-15-preview"

Write-Host "🧠 Generating Terraform for prompt: $Prompt"

$Body = @{
    messages = @(
        @{
            role    = "system"
            content = @"
You are an Azure Terraform expert.
Generate ONLY valid Terraform HCL code.
Start directly with terraform/provider blocks.
Do not include markdown, explanations, or backticks.
Ensure all braces match correctly.
"@
        },
        @{
            role    = "user"
            content = "Generate Terraform to create: $Prompt. Include RG, VNet, Subnet, NSG, Public IP, NIC, and Ubuntu VM."
        }
    )
    max_tokens = 1500
} | ConvertTo-Json -Depth 5

$Headers = @{
    "api-key"      = $OpenAIKey
    "Content-Type" = "application/json"
}

$Uri = "$OpenAIEndpoint/openai/deployments/$DeploymentName/chat/completions?api-version=$ApiVersion"
Write-Host "📡 Calling model at: $Uri"

try {
    $Response = Invoke-RestMethod -Uri $Uri -Method POST -Headers $Headers -Body $Body -ErrorAction Stop
    $TfCode = $Response.choices[0].message.content

    $TfCode = $TfCode -replace '```hcl', ''
    $TfCode = $TfCode -replace '```', ''
    $TfCode = $TfCode.Trim()

    Set-Content -Path "main.tf" -Value $TfCode -Encoding UTF8
    Write-Host "✅ Terraform code generated successfully!"
}
catch {
    Write-Host "❌ API call failed:"
    Write-Host $_.Exception.Message
    exit 1
}

if (Test-Path "main.tf" -and (Get-Content "main.tf").Length -gt 0) {
    terraform fmt
    terraform validate
    terraform init
    terraform apply -auto-approve
} else {
    Write-Host "⚠️ main.tf is empty — nothing to apply."
}

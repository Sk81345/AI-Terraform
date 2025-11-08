param (
    [string]$Prompt
)

# === Initialize Variables ===
$OpenAIEndpoint = $env:AZURE_OPENAI_ENDPOINT.TrimEnd('/')
$OpenAIKey      = $env:AZURE_OPENAI_KEY
$DeploymentName = "gpt4o-deploy"
$ApiVersion     = "2024-02-15-preview"

# === If no prompt passed (e.g., local run), ask user ===
if (-not $Prompt) {
    $Prompt = Read-Host "Enter your VM creation prompt (e.g., Create Ubuntu VM in EastUS named NextOpsLVM07)"
}

Write-Host "`n🧠 Generating Terraform for prompt: $Prompt"
$Uri = "$OpenAIEndpoint/openai/deployments/$DeploymentName/chat/completions?api-version=$ApiVersion"
Write-Host "📡 Calling model at: $Uri`n"

# === Build Request Body ===
$Body = @{

    messages = @(
        @{
            role    = "system"
            content = @"
You are an Azure Terraform expert.
Generate ONLY valid Terraform HCL code.
Start directly with terraform/provider/resource blocks.
Do NOT include markdown, explanations, comments, or backticks.
Ensure all braces and quotes are properly matched.
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

# === Call Azure OpenAI ===
try {
    $Response = Invoke-RestMethod -Uri $Uri -Method POST -Headers $Headers -Body $Body -ErrorAction Stop
    $TfCode = $Response.choices[0].message.content

    # 🧹 Clean Markdown/Formatting
    $TfCode = $TfCode -replace '```hcl', ''
    $TfCode = $TfCode -replace '```', ''
    $TfCode = $TfCode.Trim()

    # 💾 Write Terraform File
    Set-Content -Path "main.tf" -Value $TfCode -Encoding UTF8
    Write-Host "✅ Terraform code generated successfully!"
}
catch {
    Write-Host "❌ API call failed:"
    Write-Host $_.Exception.Message
    exit 1
}

# === Validate and Apply Terraform ===
if ((Test-Path "main.tf") -and ((Get-Content "main.tf" | Measure-Object -Line).Lines -gt 0)) {
    Write-Host "`n🔍 Validating Terraform..."
    terraform fmt
    terraform validate

    Write-Host "`n🚀 Initializing Terraform..."
    terraform init

    Write-Host "`n⚙️ Applying Terraform changes..."
    terraform apply -auto-approve

    Write-Host "`n✅ Deployment completed successfully!"
}
else {
    Write-Host "`n⚠️ main.tf is empty — nothing to apply."
}

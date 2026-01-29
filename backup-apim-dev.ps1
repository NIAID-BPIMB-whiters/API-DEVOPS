# APIM DEV Environment Backup Script
# Generated: January 28, 2026
# Purpose: Backup niaid-bpimb-apim-dev configuration before migration

param(
    [string]$ResourceGroup = "niaid-bpimb-apim-dev-rg",
    [string]$ApimName = "niaid-bpimb-apim-dev",
    [string]$BackupPath = ".\backup-dev-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
)

Write-Host "Starting backup of $ApimName in $ResourceGroup" -ForegroundColor Green
New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null

# 1. Export APIM ARM Template
Write-Host "Exporting APIM ARM template..." -ForegroundColor Yellow
$armTemplate = az apim show --resource-group $ResourceGroup --name $ApimName --output json
$armTemplate | Out-File "$BackupPath\apim-arm-template.json" -Encoding UTF8

# 2. Export APIM Configuration Details
Write-Host "Exporting APIM configuration details..." -ForegroundColor Yellow
$apimConfig = az apim show --resource-group $ResourceGroup --name $ApimName --output json
$apimConfig | Out-File "$BackupPath\apim-config.json" -Encoding UTF8

# 3. Export APIs
Write-Host "Exporting APIs..." -ForegroundColor Yellow
$apis = az apim api list --resource-group $ResourceGroup --service-name $ApimName --output json | ConvertFrom-Json
foreach ($api in $apis) {
    Write-Host "  Exporting API: $($api.name)" -ForegroundColor Gray
    $apiDetails = az apim api show --resource-group $ResourceGroup --service-name $ApimName --api-id $api.name --output json
    $apiDetails | Out-File "$BackupPath\api-$($api.name).json" -Encoding UTF8

    # Export API policies
    try {
        $apiPolicy = az apim api policy show --resource-group $ResourceGroup --service-name $ApimName --api-id $api.name --output json
        if ($apiPolicy) {
            $apiPolicy | Out-File "$BackupPath\api-$($api.name)-policy.json" -Encoding UTF8
        }
    } catch {
        Write-Host "    No policy found for API: $($api.name)" -ForegroundColor Gray
    }
}

# 4. Export Products
Write-Host "Exporting Products..." -ForegroundColor Yellow
$products = az apim product list --resource-group $ResourceGroup --service-name $ApimName --output json | ConvertFrom-Json
foreach ($product in $products) {
    Write-Host "  Exporting Product: $($product.name)" -ForegroundColor Gray
    $productDetails = az apim product show --resource-group $ResourceGroup --service-name $ApimName --product-id $product.name --output json
    $productDetails | Out-File "$BackupPath\product-$($product.name).json" -Encoding UTF8

    # Export product policies
    try {
        $productPolicy = az apim product policy show --resource-group $ResourceGroup --service-name $ApimName --product-id $product.name --output json
        if ($productPolicy) {
            $productPolicy | Out-File "$BackupPath\product-$($product.name)-policy.json" -Encoding UTF8
        }
    } catch {
        Write-Host "    No policy found for Product: $($product.name)" -ForegroundColor Gray
    }
}

# 5. Export Named Values (without secrets)
Write-Host "Exporting Named Values..." -ForegroundColor Yellow
$namedValues = az apim nv list --resource-group $ResourceGroup --service-name $ApimName --output json | ConvertFrom-Json
$namedValues | ConvertTo-Json | Out-File "$BackupPath\named-values.json" -Encoding UTF8

# 6. Export Subscriptions
Write-Host "Exporting Subscriptions..." -ForegroundColor Yellow
$subscriptions = az apim subscription list --resource-group $ResourceGroup --service-name $ApimName --output json | ConvertFrom-Json
$subscriptions | ConvertTo-Json | Out-File "$BackupPath\subscriptions.json" -Encoding UTF8

# 7. Export Backends
Write-Host "Exporting Backends..." -ForegroundColor Yellow
$backends = az apim backend list --resource-group $ResourceGroup --service-name $ApimName --output json | ConvertFrom-Json
$backends | ConvertTo-Json | Out-File "$BackupPath\backends.json" -Encoding UTF8

# 8. Export Global Policy
Write-Host "Exporting Global Policy..." -ForegroundColor Yellow
try {
    $globalPolicy = az apim policy show --resource-group $ResourceGroup --service-name $ApimName --output json
    $globalPolicy | Out-File "$BackupPath\global-policy.json" -Encoding UTF8
} catch {
    Write-Host "  No global policy found" -ForegroundColor Gray
}

# 9. Export Network Configuration
Write-Host "Exporting Network Configuration..." -ForegroundColor Yellow
$currentVnet = az apim show --resource-group $ResourceGroup --name $ApimName --query "{vnet:virtualNetworkType, subnet:subnetResourceId}" --output json
$currentVnet | Out-File "$BackupPath\network-config.json" -Encoding UTF8

# 10. Create Backup Summary
Write-Host "Creating backup summary..." -ForegroundColor Yellow
$summary = @{
    BackupDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    ResourceGroup = $ResourceGroup
    ApimName = $ApimName
    ApimConfig = $apimConfig | ConvertFrom-Json
    ApiCount = $apis.Count
    ProductCount = $products.Count
    NamedValueCount = $namedValues.Count
    SubscriptionCount = $subscriptions.Count
    BackendCount = $backends.Count
    BackupPath = $BackupPath
}

$summary | ConvertTo-Json -Depth 10 | Out-File "$BackupPath\backup-summary.json" -Encoding UTF8

Write-Host "Backup completed successfully!" -ForegroundColor Green
Write-Host "Backup location: $BackupPath" -ForegroundColor Green
Write-Host "Files created:" -ForegroundColor Green
Get-ChildItem $BackupPath | Select-Object Name | Format-Table -AutoSize
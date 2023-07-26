# Variables List

$AKS_RG="rg-aks-cluster"                                    # Resource Group Name
$AKS_NAME="aks-cluster-test"                                # Azure Kubernetes Service Name
$STORAGE_ACCOUNT_NAME="saakstestimran01"                    # Storage Account Name
$DELETE_FLAG =$true
# Check if Storage Account Exists and if Exist then Delete (No wait will run in background)

if ((az storage account show --name $STORAGE_ACCOUNT_NAME --resource-group $AKS_RG --query "id") -ne $null){
    Write-Host "`n Storage Account $STORAGE_ACCOUNT_NAME Deletion Initiated" -Foreground Magenta
    az storage account delete --name $STORAGE_ACCOUNT_NAME --resource-group $AKS_RG --yes
    Write-Host "`n Storage Account $STORAGE_ACCOUNT_NAME Deleted Successfully!!!" -Foreground Magenta
}
else{
    Write-Host "`n Error: Storage Account $STORAGE_ACCOUNT_NAME does not exist" -Foreground Red
    $DELETE_FLAG = $false
}

# Check if Azure Kubernetes Services (AKS) Exists and if Exist then Delete (No wait will run in background)

if ((az aks show --name $AKS_NAME --resource-group $AKS_RG --query "id") -ne $null) {
    az aks delete --name $AKS_NAME --resource-group $AKS_RG --yes --no-wait
    Write-Host "`n AKS Cluster $AKS_NAME Deletion Initiated" -Foreground Magenta
}
else{
    Write-Host "`n Error: AKS Cluster $AKS_NAME does not exist" -Foreground Red
    $DELETE_FLAG = $false
}

# Check if Azure Resource Group (RG) Exists and if Exist then Delete (No wait will run in background)

if ((az group show --name $AKS_RG --query "id") -ne $null){
    az group delete --name $AKS_RG --yes --no-wait
    Write-Host "`n Resource Group $AKS_RG Deletion Initiated" -Foreground Magenta
}
else{
    Write-Host "`n Error: Resource Group $AKS_RG does not exist" -Foreground Red
    $DELETE_FLAG = $false
}

if ($DELETE_FLAG -eq $true) {
Write-Host "`n `e[1mCongratulations AKS and Resource Group Deletion Initiated. Deletion will happen in Background and can take few minutes `e[0m " -Foreground DarkMagenta
}
else{
    Write-Host "`n `e[1mWarning: One or more resource deletion failed. Please proceed deleting resources manually `e[0m" -Foreground Red
}
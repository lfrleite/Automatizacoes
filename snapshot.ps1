<#.DESCRIPTION
Cria snapshots de todos os discos de VMs inseridas via arquivo CSV, com Tags definidas no script.

.NOTES
    Author: Luan Victor Cordeiro Levandoski
    Co-Author: Luiz Felipe Ruiz Leite
#>
### IMPORTANTE!! - ATIVE O PIM ANTES DE CONTINUAR ESSA AÇÃO ###

# Executar o arquivo 'snapshot.ps1' incluindo os parâmetros -TenantId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" -ResourceGroupName "nomedoRG".
param (
    [Parameter(Mandatory)] [String]$TenantId,
    [Parameter(Mandatory)] [String]$ResourceGroupName
)
Connect-AzAccount -TenantId $TenantId

# Importar um arquivo CSV com o caminho ".\snapshot.csv" (Mesma pasta onde está localizado o arquivo 'snapshot.ps1'), necessário ter duas colunas, uma com o nome da VM e outra com o ID da assinatura.
$VMsList = Import-Csv -Path ".\snapshot.csv" -Delimiter ","

#### Seção configuravel ####

# Defina as Tags que serão aplicadas aos snapshots.
$Tags = @{
    Chamado      = "202221"
    Solicitante  = "Luiz Felipe"
    "Excluir em" = "15/08/2021"
}
$Choice = Read-Host "
VMs que serão realizadas os snapshots de todos os discos: $VMsList
Tags: Chamado: $($Tags.Chamado), Solicitante: $($Tags.Solicitante), Excluir: $($Tags.'Excluir em')) 
Deseja continuar? (S/N)"
if ($Choice -ne "S") { exit }
$Disks = @()
foreach ($VM in $VMsList) {
    
    ## Não lista disco não gerenciado.
    $Query = Search-AzGraph -Query "
    Resources
    | where type == 'microsoft.compute/disks'
    | where tostring(split(managedBy, '/')[-1]) == '$($VM.VM)' and subscriptionId == '$($VM.SubscriptionId)'
    | project subscriptionId, location, resourceGroup, VMName = tostring(split(managedBy, '/')[-1]), DiskName = name, id"
    $Disks += $Query
    
    # Se a consulta não retornar resultados para a VM atual, exibe uma mensagem de erro e encerra o script.
    if ($Query.Count -eq 0) {
        Write-Host "Não foi encontrado a VM $($VM.VM) na assinatura $($VM.subscriptionId), favor inserir um arquivo csv válido." -ForegroundColor Red
        exit  
    }
}
$timestamp = Get-Date -f ddMMyyyy
foreach ($Disk in $Disks) {
    
    ## Se o ID de assinatura do disco for diferente da assinatura atual, altere a assinatura.
    if ($Disk.subscriptionId -ne (Get-AzContext).Subscription.Id) {
        Select-AzSubscription -SubscriptionId $Disk.subscriptionId -TenantId $TenantId | Out-Null
    }
    try {
        $Snapshotconfig = New-AzSnapshotConfig  -Location "$($Disk.location)" -SourceUri "$($Disk.id)" -AccountType Standard_LRS -CreateOption copy 
        $SnapshotName = $Disk.DiskName + "_" + $timestamp 
        $Resource = New-AzSnapshot -ResourceGroupName $ResourceGroupName -Snapshot $Snapshotconfig -SnapshotName $SnapshotName
        New-AzTag -ResourceId $Resource.Id -Tag $Tags -ErrorAction Continue
    } catch {
        $Choice = Read-Host "Um erro ocorreu ao criar o snapshot do disco, $($Disk.DiskName): $($_.Exception.Message)
        Deseja continuar? (S/N)"
        if ($Choice -ne "S") { exit }
    }
}
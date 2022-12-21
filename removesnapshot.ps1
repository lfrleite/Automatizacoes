<#.DESCRIPTION
Remove os snapshots com Tags definidas como: "Chamado".

.NOTES
    Author: Luan Victor Cordeiro Levandoski
    Co-Author: Luiz Felipe Ruiz Leite
#>

### IMPORTANTE!! - ATIVE O PIM ANTES DE CONTINUAR ESSA AÇÃO ###

# Executar o arquivo 'snapshot.ps1' incluindo os parâmetros -TenantId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" -Chamado "NumerodoChamado".
param (
    [Parameter(Mandatory)] [String]$TenantId,
    [Parameter(Mandatory)] [String]$Chamado
)
Connect-AzAccount -TenantId $TenantId

#### Seção configuravel ####

$Query = Search-AzGraph -Query "
    resources
    | where type == 'microsoft.compute/snapshots'
    | where isnotnull(tags.Chamado)
    | where tags.Chamado == '$Chamado'
    | project subscriptionId, location, resourceGroup, name, chamado = tags.Chamado"
foreach ($SnapshotName in $Query) {
    
    ## Se o ID de assinatura do disco for diferente da assinatura atual, altere a assinatura
    if ($SnapshotName.subscriptionId -ne (Get-AzContext).Subscription.Id) {
        Select-AzSubscription -SubscriptionId $SnapshotName.subscriptionId -TenantId $TenantId | Out-Null
    }
    try {
        Remove-AzSnapshot -ResourceGroupName $SnapshotName.resourceGroup -SnapshotName $SnapshotName.name
    } catch {
        $Choice = Read-Host "Um erro ocorreu ao criar o snapshot do disco, $($SnapshotName.name): $($_.Exception.Message)
        Deseja continuar? (S/N)"
        if ($Choice -ne "S") { exit }
    }
}
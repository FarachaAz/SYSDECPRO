# Script PowerShell pour planification automatique ETL
# Auteur: FarachaAz / SYSDECPRO
# Date: 2025-11-18

param(
    [switch]$CreateTask,
    [switch]$RemoveTask,
    [string]$TaskName = "ETL_Football_Daily",
    [string]$ScheduleTime = "02:00"
)

$ProjectPath = "C:\Users\Fares\Videos\SYSDECPRO\TRANSFORM\R2W"
$BatchFile = Join-Path $ProjectPath "run_etl_scheduled.bat"

function Create-ScheduledTask {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Création tâche planifiée ETL" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Nom de la tâche : $TaskName" -ForegroundColor Yellow
    Write-Host "Heure d'exécution : $ScheduleTime (quotidien)" -ForegroundColor Yellow
    Write-Host "Script batch : $BatchFile" -ForegroundColor Yellow
    Write-Host ""
    
    # Vérifier si la tâche existe déjà
    $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existingTask) {
        Write-Host "⚠️  La tâche '$TaskName' existe déjà!" -ForegroundColor Yellow
        $response = Read-Host "Voulez-vous la remplacer? (O/N)"
        if ($response -ne 'O') {
            Write-Host "Annulation." -ForegroundColor Red
            return
        }
        Write-Host "Suppression de l'ancienne tâche..." -ForegroundColor Yellow
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    }
    
    # Créer la tâche planifiée
    Write-Host "Création de la nouvelle tâche..." -ForegroundColor Green
    
    $action = New-ScheduledTaskAction -Execute $BatchFile -WorkingDirectory $ProjectPath
    $trigger = New-ScheduledTaskTrigger -Daily -At $ScheduleTime
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopIfGoingOnBatteries -AllowStartIfOnBatteries
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
    
    Register-ScheduledTask -TaskName $TaskName `
                          -Action $action `
                          -Trigger $trigger `
                          -Settings $settings `
                          -Principal $principal `
                          -Description "Chargement automatique ETL pour Football Data Warehouse"
    
    Write-Host ""
    Write-Host "✅ Tâche planifiée créée avec succès!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Pour gérer la tâche:" -ForegroundColor Cyan
    Write-Host "  - Ouvrir: taskschd.msc" -ForegroundColor White
    Write-Host "  - Rechercher: $TaskName" -ForegroundColor White
    Write-Host ""
    Write-Host "Pour exécuter manuellement:" -ForegroundColor Cyan
    Write-Host "  Start-ScheduledTask -TaskName '$TaskName'" -ForegroundColor White
    Write-Host ""
}

function Remove-ScheduledTask {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Suppression tâche planifiée ETL" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if (-not $existingTask) {
        Write-Host "❌ La tâche '$TaskName' n'existe pas." -ForegroundColor Red
        return
    }
    
    Write-Host "Suppression de la tâche '$TaskName'..." -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    
    Write-Host ""
    Write-Host "✅ Tâche planifiée supprimée avec succès!" -ForegroundColor Green
    Write-Host ""
}

function Show-TaskInfo {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Informations tâche planifiée ETL" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if (-not $task) {
        Write-Host "❌ La tâche '$TaskName' n'existe pas." -ForegroundColor Red
        Write-Host ""
        Write-Host "Pour créer la tâche:" -ForegroundColor Cyan
        Write-Host "  .\schedule_etl.ps1 -CreateTask" -ForegroundColor White
        return
    }
    
    $taskInfo = Get-ScheduledTaskInfo -TaskName $TaskName
    
    Write-Host "📋 Nom : $($task.TaskName)" -ForegroundColor Yellow
    Write-Host "📝 Description : $($task.Description)" -ForegroundColor Yellow
    Write-Host "📅 Déclencheur : $($task.Triggers[0].CimClass.CimClassName)" -ForegroundColor Yellow
    Write-Host "⏰ Prochaine exécution : $($taskInfo.NextRunTime)" -ForegroundColor Yellow
    Write-Host "✅ Dernière exécution : $($taskInfo.LastRunTime)" -ForegroundColor Yellow
    Write-Host "🔄 Dernière résultat : $($taskInfo.LastTaskResult)" -ForegroundColor Yellow
    Write-Host "📂 Répertoire : $ProjectPath" -ForegroundColor Yellow
    Write-Host ""
    
    Write-Host "Commandes utiles:" -ForegroundColor Cyan
    Write-Host "  Exécuter maintenant : Start-ScheduledTask -TaskName '$TaskName'" -ForegroundColor White
    Write-Host "  Désactiver : Disable-ScheduledTask -TaskName '$TaskName'" -ForegroundColor White
    Write-Host "  Activer : Enable-ScheduledTask -TaskName '$TaskName'" -ForegroundColor White
    Write-Host "  Supprimer : .\schedule_etl.ps1 -RemoveTask" -ForegroundColor White
    Write-Host ""
}

# Exécution selon paramètres
if ($CreateTask) {
    Create-ScheduledTask
}
elseif ($RemoveTask) {
    Remove-ScheduledTask
}
else {
    Show-TaskInfo
}

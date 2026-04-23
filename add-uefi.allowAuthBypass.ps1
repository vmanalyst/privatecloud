Connect-VIServer "vcenter01.ash.local"
$VMNames = Get-Content "C:\Scripts\pk_vmlist.txt"
$LogFile = "C:\Scripts\PK_VMX_Results.txt"
Write-Host "Gathering VM data..." -ForegroundColor Yellow
$TargetVMs = Get-VM | Where-Object { $VMNames -contains $_.Name }
foreach ($VM in $TargetVMs) {
    # --- FILTERS ---
    $SkipReason = $null
    if ($VM.ExtensionData.Config.Template) { $SkipReason = "Template" }
    elseif ($VM.ExtensionData.Config.Firmware -ne "efi") { $SkipReason = "BIOS firmware — not affected" }
    elseif (-not $VM.ExtensionData.Config.BootOptions.EfiSecureBootEnabled) { $SkipReason = "Secure Boot disabled — not affected" }
    if ($SkipReason) {
        Write-Host "Skipping: $($VM.Name) [$SkipReason]" -ForegroundColor Gray
        "$($VM.Name) - SKIPPED: $SkipReason" | Add-Content $LogFile
        continue
    }
    # --- SHOW CHANGE SUMMARY ---
    Write-Host "`n==========================================" -ForegroundColor White
    Write-Host "Target VM: $($VM.Name)" -ForegroundColor Cyan
    Write-Host "Action:    Set uefi.allowAuthBypass = TRUE"
    $Confirm = Read-Host "Apply? (ENTER to confirm, 'S' to skip, Ctrl+C to stop)"
    if ($Confirm -eq 's') {
        Write-Host "Skipped by user." -ForegroundColor Yellow
        "$($VM.Name) - SKIPPED: User choice" | Add-Content $LogFile
        continue
    }
    # --- EXECUTION ---
    try {
        $spec      = New-Object VMware.Vim.VirtualMachineConfigSpec
        $opt       = New-Object VMware.Vim.OptionValue
        $opt.Key   = "uefi.allowAuthBypass"
        $opt.Value = "TRUE"
        $spec.ExtraConfig = @($opt)
        $VM.ExtensionData.ReconfigVM($spec)
        Write-Host "VERIFYING..." -NoNewline
        $Verify = (Get-VM $VM.Name).ExtensionData.Config.ExtraConfig | 
                  Where-Object { $_.Key -eq "uefi.allowAuthBypass" }
        if ($Verify.Value -eq "TRUE") {
            Write-Host " [OK] uefi.allowAuthBypass set successfully." -ForegroundColor Green
            "$($VM.Name) - SUCCESS" | Add-Content $LogFile
        } else {
            Write-Host " [WARN] Parameter not found after apply — check manually." -ForegroundColor Yellow
            "$($VM.Name) - WARN: Could not verify" | Add-Content $LogFile
        }
    } catch {
        Write-Host " [ERROR] $($_.Exception.Message)" -ForegroundColor Red
        "$($VM.Name) - FAILED: $($_.Exception.Message)" | Add-Content $LogFile
    }
    # --- PAUSE BEFORE NEXT VM ---
    Read-Host "`nPress ENTER to continue to next VM"
}
Disconnect-VIServer * -Confirm:$false

$VM = Get-VM -Name "YOUR-VM-NAME"
$spec      = New-Object VMware.Vim.VirtualMachineConfigSpec
$opt       = New-Object VMware.Vim.OptionValue
$opt.Key   = "uefi.allowAuthBypass"
$opt.Value = "TRUE"
$spec.ExtraConfig = @($opt)
$VM.ExtensionData.ReconfigVM($spec)
Write-Host "Done - uefi.allowAuthBypass set on $($VM.Name)" -ForegroundColor Green


# Verification 
(Get-VM -Name "YOUR-VM-NAME").ExtensionData.Config.ExtraConfig | 
    Where-Object { $_.Key -eq "uefi.allowAuthBypass" }

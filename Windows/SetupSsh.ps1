param(
    [parameter(mandatory)][string]$publicKey
)


# Install the OpenSSH Client/Server
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0;
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0;

# OPTIONAL but recommended: Set StartupType to automatic
Set-Service -Name sshd -StartupType Automatic;

# Now start the sshd service to generate default configuration
Start-Service sshd;

# Confirm the Firewall rule is configured. It should be created automatically by setup. Run the following to verify
if (!(Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue | Select-Object Name, Enabled)) {
    Write-Output "Firewall Rule OpenSSH-Server-In-TCP does not exist, creating it...";
    New-NetFirewallRule -Name OpenSSH-Server-In-TCP -DisplayName OpenSSH Server (sshd) -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22;
} else {
    Write-Output "Firewall rule OpenSSH-Server-In-TCP has been created and exists.";
}

# Disable password authentication
(Get-Content -Path $env:programdata\ssh\sshd_config).Replace(
    "#PasswordAuthentication yes",
    "PasswordAuthentication no").Replace(
    "#PubkeyAuthentication yes",
    "PubkeyAuthentication yes") | Set-Content -Path $env:programdata\ssh\sshd_config

# Set default shell to PowerShell
New-ItemProperty -Path HKLM:\SOFTWARE\OpenSSH -Name DefaultShell -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -PropertyType String -Force;

# Add our public key
Write-Output $publicKey | Add-Content $env:programdata\ssh\administrators_authorized_keys;
icacls.exe $env:programdata\ssh\administrators_authorized_keys /inheritance:r /grant Administrators:F /grant SYSTEM:F;

# Now start the sshd service
Restart-Service sshd;

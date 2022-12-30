Add-Type -AssemblyName System.Windows.Forms
$balloon = New-Object System.Windows.Forms.NotifyIcon
$balloon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon((Get-Process -id $pid).Path)
$balloon.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Warning
$balloon.BalloonTipText = "Please go back to the terminal to cleanup after the installation."
$balloon.BalloonTipTitle = "Hey $Env:USERNAME"
$balloon.Visible = $true

$Releases = (Invoke-WebRequest -Uri "https://www.python.org/downloads/windows/").Links.Href | Get-Unique
$LatestReleaseLink = $($Releases | Select-String -Pattern "/downloads/release/python.*" -AllMatches).Matches[0]
$DownloadPage = (Invoke-WebRequest -Uri "https://www.python.org/${LatestReleaseLink}").Links.Href | Get-Unique
$DownloadLink = ($DownloadPage | Select-String -Pattern "https://www.python.org/ftp/python/.*/.*(?<!embed-)-amd64.exe$").Matches[0].Value

Invoke-WebRequest -Uri $DownloadLink -OutFile ".\python-latest.exe"
Start-Process -FilePath .\python-latest.exe -Wait -WindowStyle Maximized
$balloon.ShowBalloonTip(5000)
Remove-Item -Path .\python-latest.exe -Verbose -Confirm

# Port knock client for the OpenWrt router.
#   .\knock.ps1 open    -> opens SSH/HTTP/HTTPS for this PC's IP (auto-closes after 1 h idle)
#   .\knock.ps1 close   -> reverse knock, locks them again immediately
# Put the same three UDP ports you used in nftables.d/90-portknock.nft below, and keep your copy private.
param(
    [Parameter(Mandatory = $true)][ValidateSet('open', 'close')][string]$Action,
    [string]$Router = '192.168.1.2'
)

$sequence = @(0, 0, 0)   # <KNOCK_PORT_1>, <KNOCK_PORT_2>, <KNOCK_PORT_3>
if ($Action -eq 'close') { [array]::Reverse($sequence) }

$udp = New-Object System.Net.Sockets.UdpClient
$payload = [byte[]](0)
foreach ($port in $sequence) {
    [void]$udp.Send($payload, $payload.Length, $Router, $port)
    Start-Sleep -Milliseconds 300
}
$udp.Close()

if ($Action -eq 'open') { Write-Host "Knocked open. SSH: ssh root@$Router" } else { Write-Host "Locked again." }

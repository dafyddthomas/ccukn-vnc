# VNC Setup for CCUK

## Windows


Default (installs if needed, sets ccp2003!, opens firewall):

`.\Setup-TightVNC.ps1`

Reconfigure only (no web client firewall):

`.\Setup-TightVNC.ps1 -OpenFirewall:$false`

Also set a view-only password:

`.\Setup-TightVNC.ps1 -SetViewOnly -ViewOnlyPassword "ccp2003!"`

## macOS 

run 

`sudo bash setup-macos-vnc.sh`

## RPI

run

`sudo bash setup-vnc.sh`

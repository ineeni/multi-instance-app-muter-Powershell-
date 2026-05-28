# Multi-Instance App Muter (PowerShell)

A lightweight, pure PowerShell tool to control audio volume on a per-application/session basis under Windows, without needing external DLLs or utilities.

This script targets all processes with the target name and applies mute or unmute depending on the state at the time the script is run.

Intended to be deployed via hotkey or shortcut.  
The script will take action at the time of run and close.

See the `instance-specific` branch for the version that targets specific windows/character names.

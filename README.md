# Multi-Instance App Muter (PowerShell) - Instance Specific

A lightweight, pure PowerShell tool to control audio volume on a per-application/session basis under Windows, targeting specific instances (such as individual character windows).

This script targets specific instances matching the target window title/character name and applies mute or unmute depending on the state at the time the script is run.

Intended to be deployed via hotkey or shortcut.  
The script will take action at the time of run and close.

See the `main` branch for the global version that targets all instances of a process.

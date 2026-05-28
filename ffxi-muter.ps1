# =====================================================================
# FFXI SOUND SESSION MUTER (CoreAudio WASAPI Interop - Fully Fixed)
# Target Process: pol.exe
# Behavior: Toggle Mute (Global - All Instances)
# =====================================================================

# Generate a unique session namespace to bypass PowerShell's Add-Type cache lock
$SessionId = Get-Random -Minimum 100000 -Maximum 999999
$Namespace = "FFXIMuter_$SessionId"

$Signature = @"
using System;
using System.Runtime.InteropServices;
using System.Diagnostics;

namespace $Namespace {
    [ComImport]
    [Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
    internal class MMDeviceEnumerator { }

    [Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IMMDeviceEnumerator {
        int EnumAudioEndpoints(int dataFlow, int dwStateMask, out IntPtr ppDevices);
        int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice ppDevice);
    }

    [Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IMMDevice {
        int Activate(ref Guid iid, int dwClsCtx, IntPtr pActivationParams, [MarshalAs(UnmanagedType.IUnknown)] out object ppInterface);
    }

    [Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IAudioSessionManager2 {
        int GetAudioSessionControl(IntPtr AudioSessionGuid, uint StreamFlags, out IntPtr SessionControl);
        int GetSimpleAudioVolume(IntPtr AudioSessionGuid, uint StreamFlags, out IntPtr AudioVolume);
        int GetSessionEnumerator(out IAudioSessionEnumerator SessionEnum);
    }

    [Guid("E2F5BB11-0570-40CA-ACDD-3AA01277DEE8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IAudioSessionEnumerator {
        int GetCount(out int SessionCount);
        int GetSession(int SessionIdx, [MarshalAs(UnmanagedType.IUnknown)] out object Session);
    }

    [Guid("BFB7FF88-7239-4FC9-8FA2-07C950BE9C6D"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IAudioSessionControl2 {
        int GetState(out int pRetVal);
        int GetDisplayName([MarshalAs(UnmanagedType.LPWStr)] out string pRetVal);
        int SetDisplayName([MarshalAs(UnmanagedType.LPWStr)] string Value, ref Guid EventContext);
        int GetIconPath([MarshalAs(UnmanagedType.LPWStr)] out string pRetVal);
        int SetIconPath([MarshalAs(UnmanagedType.LPWStr)] string Value, ref Guid EventContext);
        int GetGroupingParam(out Guid pRetVal);
        int SetGroupingParam(ref Guid Override, ref Guid EventContext);
        int RegisterAudioSessionNotification(IntPtr client);
        int UnregisterAudioSessionNotification(IntPtr client);
        int GetSessionIdentifier([MarshalAs(UnmanagedType.LPWStr)] out string pRetVal);
        int GetSessionInstanceIdentifier([MarshalAs(UnmanagedType.LPWStr)] out string pRetVal);
        int GetProcessId(out uint pRetVal);
    }

    [Guid("87CE5498-68D6-44E5-9215-6DA47EF883D8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface ISimpleAudioVolume {
        int SetMasterVolume(float fLevel, ref Guid EventContext);
        int GetMasterVolume(out float pfLevel);
        int SetMute(bool bMute, ref Guid EventContext);
        int GetMute([MarshalAs(UnmanagedType.Bool)] out bool pbMute);
    }

    public class SoundController {
        public static string ToggleMute(string targetName) {
            targetName = targetName.ToLower().Trim();
            if (targetName.EndsWith(".exe")) {
                targetName = targetName.Substring(0, targetName.Length - 4);
            }

            var enumerator = (IMMDeviceEnumerator)new MMDeviceEnumerator();
            IMMDevice device;
            int hr = enumerator.GetDefaultAudioEndpoint(0, 1, out device);
            if (hr != 0) return "Failed to retrieve default endpoint. HRESULT: " + hr;

            Guid iidIAudioSessionManager2 = new Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F");
            object mgrObj;
            hr = device.Activate(ref iidIAudioSessionManager2, 1, IntPtr.Zero, out mgrObj);
            if (hr != 0) return "Failed to activate audio manager. HRESULT: " + hr;

            var manager = (IAudioSessionManager2)mgrObj;
            IAudioSessionEnumerator sessionEnum;
            hr = manager.GetSessionEnumerator(out sessionEnum);
            if (hr != 0) return "Failed to get audio sessions. HRESULT: " + hr;

            int count;
            sessionEnum.GetCount(out count);
            int matchedCount = 0;

            for (int i = 0; i < count; i++) {
                object sessionObj;
                hr = sessionEnum.GetSession(i, out sessionObj);
                if (hr != 0) continue;

                var sessionCtrl2 = sessionObj as IAudioSessionControl2;
                var simpleVolume = sessionObj as ISimpleAudioVolume;
                if (sessionCtrl2 == null || simpleVolume == null) continue;

                uint pid;
                hr = sessionCtrl2.GetProcessId(out pid);
                if (hr != 0 || pid == 0) continue;

                try {
                    using (var proc = Process.GetProcessById((int)pid)) {
                        if (proc.ProcessName.ToLower() == targetName) {
                            bool isMuted;
                            simpleVolume.GetMute(out isMuted);
                            Guid emptyGuid = Guid.Empty;
                            simpleVolume.SetMute(!isMuted, ref emptyGuid);
                            matchedCount++;
                        }
                    }
                } catch {
                    // Ignore dead processes
                }
            }
            return "Toggled " + matchedCount + " process(es).";
        }
    }
}
"@

# Compile the fresh signature definitions
Add-Type -TypeDefinition $Signature

# Safely resolve and invoke our dynamically namespaced type using standard evaluation syntax
$ControllerType = ("${Namespace}.SoundController" -as [type])
$Result = $ControllerType::ToggleMute("pol")

Write-Host $Result -ForegroundColor Cyan

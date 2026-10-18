# Godot'u kullanicinin GORMEDIGI ayri bir Windows masaustunde (CreateDesktop) calistirir (2026-10-18, kullanici sikayeti: olcum pencereleri
# ekraninda surekli aciliyor, once tam ekran sonra pencere). Pencere o masaustunde acilir: ne gorunur, ne odak calar, ne giris alir.
# GPU / Vulkan normal calisir (render-CPU olcumu gecerli); GPU suresi gorunur pencereyle birebir ayni olmayabilir.
# Kullanim (dot-source):  . "$PSScriptRoot\hidden_launch.ps1" ; $code = Invoke-GodotHidden -Exe $godot -ArgLine '--path "x" -s ...' -WorkDir $proj -TimeoutSec 600
# Cikis kodu: Godot'un cikis kodu; -1 masaustu olusturulamadi, -3 surec olusturulamadi, -2 (0xFFFFFFFE) zaman asimi (surec oldurulur).
# Guvenlik: surec bir Job Object'e konur (KILL_ON_JOB_CLOSE): bu betik/PowerShell olurse Godot da olur, gorunmez surec artakalmaz.
# Cikti: print() satirlari icin Godot'a --log-file ver (stdout bu yolda yakalanmaz).

function Add-HiddenDeskType {
	if ('HiddenDesk' -as [type]) { return }
	Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class HiddenDesk {
	[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
	public struct STARTUPINFO {
		public int cb; public string lpReserved; public string lpDesktop; public string lpTitle;
		public int dwX; public int dwY; public int dwXSize; public int dwYSize; public int dwXCountChars; public int dwYCountChars; public int dwFillAttribute;
		public int dwFlags; public short wShowWindow; public short cbReserved2; public IntPtr lpReserved2; public IntPtr hStdInput; public IntPtr hStdOutput; public IntPtr hStdError;
	}
	[StructLayout(LayoutKind.Sequential)]
	public struct PROCESS_INFORMATION { public IntPtr hProcess; public IntPtr hThread; public int dwProcessId; public int dwThreadId; }
	[StructLayout(LayoutKind.Sequential)]
	public struct JOBOBJECT_BASIC_LIMIT_INFORMATION {
		public long PerProcessUserTimeLimit; public long PerJobUserTimeLimit; public uint LimitFlags; public UIntPtr MinimumWorkingSetSize; public UIntPtr MaximumWorkingSetSize;
		public uint ActiveProcessLimit; public UIntPtr Affinity; public uint PriorityClass; public uint SchedulingClass;
	}
	[StructLayout(LayoutKind.Sequential)]
	public struct IO_COUNTERS { public ulong ReadOperationCount; public ulong WriteOperationCount; public ulong OtherOperationCount; public ulong ReadTransferCount; public ulong WriteTransferCount; public ulong OtherTransferCount; }
	[StructLayout(LayoutKind.Sequential)]
	public struct JOBOBJECT_EXTENDED_LIMIT_INFORMATION {
		public JOBOBJECT_BASIC_LIMIT_INFORMATION BasicLimitInformation; public IO_COUNTERS IoInfo;
		public UIntPtr ProcessMemoryLimit; public UIntPtr JobMemoryLimit; public UIntPtr PeakProcessMemoryUsed; public UIntPtr PeakJobMemoryUsed;
	}
	[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
	static extern IntPtr CreateDesktop(string lpszDesktop, IntPtr lpszDevice, IntPtr pDevmode, int dwFlags, uint dwDesiredAccess, IntPtr lpsa);
	[DllImport("user32.dll", SetLastError = true)] static extern bool CloseDesktop(IntPtr hDesktop);
	[DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
	static extern bool CreateProcess(string lpApplicationName, string lpCommandLine, IntPtr lpProcessAttributes, IntPtr lpThreadAttributes, bool bInheritHandles, uint dwCreationFlags, IntPtr lpEnvironment, string lpCurrentDirectory, ref STARTUPINFO lpStartupInfo, out PROCESS_INFORMATION lpProcessInformation);
	[DllImport("kernel32.dll", SetLastError = true)] static extern uint ResumeThread(IntPtr hThread);
	[DllImport("kernel32.dll", SetLastError = true)] static extern uint WaitForSingleObject(IntPtr h, uint ms);
	[DllImport("kernel32.dll", SetLastError = true)] static extern bool GetExitCodeProcess(IntPtr h, out uint code);
	[DllImport("kernel32.dll", SetLastError = true)] static extern bool TerminateProcess(IntPtr h, uint code);
	[DllImport("kernel32.dll", SetLastError = true)] static extern bool CloseHandle(IntPtr h);
	[DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)] static extern IntPtr CreateJobObject(IntPtr a, string name);
	[DllImport("kernel32.dll", SetLastError = true)] static extern bool SetInformationJobObject(IntPtr job, int infoType, IntPtr info, uint size);
	[DllImport("kernel32.dll", SetLastError = true)] static extern bool AssignProcessToJobObject(IntPtr job, IntPtr proc);

	public static int Run(string exe, string args, string workDir, string desktopName, int timeoutMs, ref string error) {
		error = "";
		IntPtr desk = CreateDesktop(desktopName, IntPtr.Zero, IntPtr.Zero, 0, 0x10000000u, IntPtr.Zero); // GENERIC_ALL
		if (desk == IntPtr.Zero) { error = "CreateDesktop hata " + Marshal.GetLastWin32Error(); return -1; }
		IntPtr job = CreateJobObject(IntPtr.Zero, null);
		IntPtr pInfo = IntPtr.Zero;
		try {
			if (job != IntPtr.Zero) {
				JOBOBJECT_EXTENDED_LIMIT_INFORMATION info = new JOBOBJECT_EXTENDED_LIMIT_INFORMATION();
				info.BasicLimitInformation.LimitFlags = 0x2000; // JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
				int sz = Marshal.SizeOf(typeof(JOBOBJECT_EXTENDED_LIMIT_INFORMATION));
				pInfo = Marshal.AllocHGlobal(sz);
				Marshal.StructureToPtr(info, pInfo, false);
				if (!SetInformationJobObject(job, 9, pInfo, (uint)sz)) { error += "SetInformationJobObject hata " + Marshal.GetLastWin32Error() + "; "; }
			}
			STARTUPINFO si = new STARTUPINFO();
			si.cb = Marshal.SizeOf(typeof(STARTUPINFO));
			si.lpDesktop = desktopName;
			PROCESS_INFORMATION pi;
			string cmd = "\"" + exe + "\" " + args;
			if (!CreateProcess(null, cmd, IntPtr.Zero, IntPtr.Zero, false, 0x4u /* CREATE_SUSPENDED */, IntPtr.Zero, workDir, ref si, out pi)) {
				error += "CreateProcess hata " + Marshal.GetLastWin32Error(); return -3;
			}
			if (job != IntPtr.Zero && !AssignProcessToJobObject(job, pi.hProcess)) { error += "AssignProcessToJobObject hata " + Marshal.GetLastWin32Error() + "; "; }
			ResumeThread(pi.hThread);
			uint w = WaitForSingleObject(pi.hProcess, (uint)timeoutMs);
			uint code = 0;
			if (w == 0x102u) { TerminateProcess(pi.hProcess, 1u); WaitForSingleObject(pi.hProcess, 5000u); code = 0xFFFFFFFEu; }
			else { GetExitCodeProcess(pi.hProcess, out code); }
			CloseHandle(pi.hThread); CloseHandle(pi.hProcess);
			return unchecked((int)code);
		} finally {
			if (pInfo != IntPtr.Zero) Marshal.FreeHGlobal(pInfo);
			if (job != IntPtr.Zero) CloseHandle(job); // kapanis: hala yasayan surec (ayni isteme ait) olur
			CloseDesktop(desk);
		}
	}
}
"@
}

function Invoke-GodotHidden {
	param([string]$Exe, [string]$ArgLine, [string]$WorkDir, [int]$TimeoutSec = 600)
	Add-HiddenDeskType
	$name = "fpsmicro_" + [guid]::NewGuid().ToString("N").Substring(0, 8)
	$err = ""
	$code = [HiddenDesk]::Run($Exe, $ArgLine, $WorkDir, $name, $TimeoutSec * 1000, [ref]$err)
	if ($err -ne "") { Write-Host "HIDDEN: $err" }
	return $code
}

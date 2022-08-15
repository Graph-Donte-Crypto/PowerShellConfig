function Wait-Task {
	param (
		[Parameter(Mandatory, ValueFromPipeline)]
		[System.Threading.Tasks.Task[]]$task
	)

	process {
		while (-not $task.AsyncWaitHandle.WaitOne(40)) { }
		$task.GetAwaiter().GetResult()
	}
}

Set-Alias -Name wait -Value Wait-Task

Add-Type -TypeDefinition @"
namespace System.IO
{
	using System;
	using System.IO;
	using System.Threading;
	using System.Threading.Tasks;
	public class ThrottledStream : Stream
	{
		public const double Infinite = 0;
		private readonly Stream BaseStream;
		private double MaximumBytesPerSecond = 0;
		private long ReadedBytes = 0;
		private long WritedBytes = 0;
		private long StartTimeMs = 0;

		protected long CurrentMilliseconds => Environment.TickCount;

		public override bool CanRead => BaseStream.CanRead;
		public override bool CanSeek => BaseStream.CanSeek;
		public override bool CanWrite => BaseStream.CanWrite;
		public override long Length => BaseStream.Length;
		public override long Position
		{
			get => BaseStream.Position;
			set => BaseStream.Position = value;
		}
		public ThrottledStream(Stream baseStream) : this(baseStream, Infinite) { }

		public ThrottledStream(Stream baseStream, double maximumBytesPerSecond)
		{
			if (maximumBytesPerSecond < 0)
				maximumBytesPerSecond = Infinite;

			BaseStream = baseStream ?? throw new ArgumentNullException("baseStream");
			MaximumBytesPerSecond = maximumBytesPerSecond;
			StartTimeMs = CurrentMilliseconds;
		}

		public override void Flush() => BaseStream.Flush();
		public new Task FlushAsync() => BaseStream.FlushAsync();
		public override Task FlushAsync(CancellationToken cancellationToken) => BaseStream.FlushAsync(cancellationToken);

		public override int Read(byte[] buffer, int offset, int count) {

			var ncount = Throttle(ReadedBytes, count).GetAwaiter().GetResult();
			ReadedBytes += ncount;
			
			return BaseStream.Read(buffer, offset, ncount);
		}

		public async new Task<int> ReadAsync(byte[] buffer, int offset, int count) {
			
			count = await Throttle(ReadedBytes, count);
			ReadedBytes += count;

			return await BaseStream.ReadAsync(buffer, offset, count).ConfigureAwait(false);
		}

		public async override Task<int> ReadAsync(byte[] buffer, int offset, int count, CancellationToken cancellationToken) {
			
			count = await Throttle(ReadedBytes, count);
			ReadedBytes += count;

			return await BaseStream.ReadAsync(buffer, offset, count, cancellationToken).ConfigureAwait(false);
		}

		public override long Seek(long offset, SeekOrigin origin) => BaseStream.Seek(offset, origin);
		public override void SetLength(long value) => BaseStream.SetLength(value);

		public override void Write(byte[] buffer, int offset, int count) {
			
			count = Throttle(WritedBytes, count).GetAwaiter().GetResult();
			WritedBytes += count;

			BaseStream.Write(buffer, offset, count);
		}
		
		public async new Task WriteAsync(byte[] buffer, int offset, int count) {
			
			count = await Throttle(WritedBytes, count);
			WritedBytes += count;

			await BaseStream.WriteAsync(buffer, offset, count).ConfigureAwait(false);
		}
		
		public async override Task WriteAsync(byte[] buffer, int offset, int count, CancellationToken cancellationToken) {
			
			count = await Throttle(WritedBytes, count);
			WritedBytes += count;

			await BaseStream.WriteAsync(buffer, offset, count, cancellationToken).ConfigureAwait(false);
		}
		
		public override string ToString() => BaseStream.ToString();

		public double AvailableBytes => System.Math.Floor(((CurrentMilliseconds - StartTimeMs) / 1000.0) * MaximumBytesPerSecond);

		protected async Task<int> Throttle(long totalProcessed, int expectedBytes) {
			if (MaximumBytesPerSecond == Infinite)
				return expectedBytes;

			var bytesToRead = await ThrottleCore(totalProcessed, (long)expectedBytes);

			if ( (long)System.Int32.MaxValue < bytesToRead)
				return System.Int32.MaxValue;
			else 
				return (int)bytesToRead;
		}

		protected async Task<long> ThrottleCore(long totalProcessed, long expectedBytes) {
			var bytesToRead = (long)(AvailableBytes - totalProcessed);
			
			if (bytesToRead == 0) {
				await Task.Delay((int)System.Math.Ceiling(1000.0 / MaximumBytesPerSecond));
				bytesToRead = await ThrottleCore(totalProcessed, expectedBytes);
			}

			return System.Math.Min(expectedBytes, bytesToRead);
		}
	}
}
"@

function ExecutionTime {
	$history = Get-History -ErrorAction Ignore -Count 1
	if ($history) {
		Write-Host "[" -NoNewline
		$ts = New-TimeSpan $history.StartExecutionTime $history.EndExecutionTime
		$time_string = ($(New-Object DateTime) + $ts).ToString("HH:mm:ss.fff")
		switch ($ts) {
			{$_.TotalSeconds -lt 1} { 
				$time_string |
					Write-Host -NoNewline -ForegroundColor DarkGreen
				break
			}
			{$_.totalminutes -lt 1} { 
				$time_string |
					Write-Host -NoNewline -ForegroundColor DarkYellow
				break
			}
			{$_.totalminutes -ge 1} { 
				$time_string |
					Write-Host -NoNewline  -ForegroundColor Red
				break
			}
		}
		Write-Host "] took " -nonewline
		$result = $history.ToString()
		Write-Host "[$result]" -foregroundcolor White
	}
}

function Nothing {
	
}

function Prompt {	

	if ($env:UserName) {
		$current_user = $env:UserName + "@" + $env:UserDomain
	}
	elseif ($env:USER) {
		$current_user = $env:USER + "@" + $env:NAME
	}
	else {
		$current_user = "unknown@UNKNOWN"
	}
	Write-Host $current_user -foregroundcolor DarkGreen -nonewline
	
	
	$current_time = " " + ($(get-date)).ToString("HH:mm:ss.fff")
	Write-Host $current_time -foregroundcolor White -nonewline


	$current_directory = " " + $pwd.path
	$current_directory = $current_directory.Replace('Microsoft.PowerShell.Core\FileSystem::', '')
	
	if (-Not $current_directory.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
		$current_directory = $current_directory + [System.IO.Path]::DirectorySeparatorChar
	}
	Write-Host $current_directory  -foregroundcolor Green -nonewline
	
	
	Write-Host ""
	
	
	return " # "
}

function FN-Enable {
	Remove-PSReadLineKeyHandler -Chord '@'
}
function FN-Disable {
	Set-PSReadLineKeyHandler -Chord '@' -ScriptBlock {}
}


function ProfileOpen {
	OpenWithNpp $PROFILE
}

function ProfileGetDirectory {
	return (Get-Item $PROFILE).Directory.FullName
}

function ProfileOpenDirectory {
	Open $(ProfileGetDirectory)
}


function SetTitle {
	param ([System.String]$Title)
	$host.ui.RawUI.WindowTitle = $Title
}

function Open {
	param ([System.String]$Path)
	Start-Process -Path $Path -Verb Open
}

function OpenWithNpp {
	param ([System.String]$Path)
	Start-Process -Path 'C:\Program Files (x86)\Notepad++\notepad++.exe' -Args "$Path" -Verb Open
}

Set-PSReadLineKeyHandler -Chord '@' -ScriptBlock {}



function SyncFolders {
	param (
	  [string]$Source,
	  [string]$Target
	)		
	
	$path_splitter = $([System.IO.Path]::DirectorySeparatorChar)
	$no_path_splitter = ''
	if ($path_splitter -eq '\') {
		$no_path_splitter = '/'
	} else {
		$no_path_splitter = '\'
	}
	
	$Source = $($Source + '/').Replace($no_path_splitter, $path_splitter)
	$Target = $($Target + '/').Replace($no_path_splitter, $path_splitter)
	
	echo $("Source: " + $Source)
	echo $("Target: " + $Target)
	
	$map = @{}
	
	Get-ChildItem -Path $Target -Recurse | ForEach-Object {
		$current_file = $_.FullName.Substring($Target.Length)
		$current_time = $_.LastWriteTime
		$map.Add($current_file, $current_time)
	}
	
	Get-ChildItem -Path $Source -Recurse | ForEach-Object {
		$current_file = $_.FullName.Substring($Source.Length)
		$current_time = $_.LastWriteTime
		if ($map.ContainsKey($current_file)) {
			$map_time = $map.Item($current_file)
			if ($map_time -lt $current_time) {
				$map.Item($current_file) = $current_time
				echo $($current_file + " has new version: old [" + $map_time.ToString() + "], new [" + $current_file.ToString() + "]")
				Copy-Item $($Source + $current_file) -Destination $($Target + $current_file) -Force
			}
		}
		else {
			$map.Add($current_file, $current_time)
			echo $($current_file + " is new file")
			Copy-Item $($Source + $current_file) -Destination $($Target + $current_file) -Force
		}
	}
	
}

function Tcp-SendMessage {
	param ( 
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()] 
		[string] $Ip,	
		[int] $Port,
		[Parameter(Mandatory, Position=0, ParameterSetName="string")]
		[ValidateNotNullOrEmpty()] 
		[string]$Message,
		[Parameter(Mandatory, Position=0, ParameterSetName="bytes")]
		[byte[]]$Bytes
	)
	process {

		if ($PSCmdlet.ParameterSetName -eq 'string') {
			Tcp-SendMessage -Ip $Ip -Port $Port -Bytes $([System.Text.Encoding]::UTF8.GetBytes($Message))
			return 
		}

		try {
			if ($Ip.Contains(':')) {
				$parts = $Ip.Split(':')
				$Ip = $parts[0]
				if ($Port -eq 0) {
					$Port = $parts[1]
				}
			}
			$Socket = New-Object System.Net.Sockets.TCPClient($Ip, $Port) 
			$Stream = $Socket.GetStream() 
			
			$Stream.Write($Bytes)
			
			$Stream.Close()
			$Socket.Close()
		}
		catch {
			"Tcp-SendMessage failed with: `n" + $Error[0]
		}
		finally {
			$Socket.Close()
		}
	}
}

function Tcp-ReceiveUTF8 {
	param ( 
		[Parameter(Mandatory=$true, Position=1)]
		[int] $Port,
		[Parameter(Position=2)]
		[double] $bps = 0
	)
	process {
		Tcp-ReceiveBytesArray -Port $Port -bps $bps | % {
			Write-Output $([System.Text.Encoding]::UTF8.GetString($($_[0] -as [byte[]])))
		}
	}
}

function Tcp-ReceiveFile {
	param ( 
		[Parameter(Mandatory, Position=1)]
		[int] $Port,
		[Parameter(Mandatory, Position=2)]
		[string] $File,
		[Parameter(Position=3)]
		[double] $bps = 0
	)
	process {
		try {
			$stream = [System.IO.File]::Create($File)
			Tcp-ReceiveBytesArray -Port $Port -bps $bps | % {
				$bytes = $($_[0] -as [byte[]])
				$stream.Write($bytes, 0, $bytes.Count)
				$stream.Flush()
			}
		}
		catch {
			$_
		}
		finally {
			$stream.Close()
		}
	}
}

#todo: create UTF-8 support
function Tcp-ReceiveBytesArray {
	param ( 
		[Parameter(Mandatory, Position=1)]
		[int] $Port,
		[Parameter(Position=2)]
		[double] $bps = 0
	) 
	process {
		try { 
			$endpoint_v4 = new-object System.Net.IPEndPoint([ipaddress]::Any, $Port) 
			$endpoint_v6 = new-object System.Net.IPEndPoint([ipaddress]::IPv6Any, $Port) 

			$listener_v4 = new-object System.Net.Sockets.TcpListener $endpoint_v4
			$listener_v6 = new-object System.Net.Sockets.TcpListener $endpoint_v6

			$listener_v4.start() 
			$listener_v6.start() 
			
			$task_v4 = $listener_v4.AcceptTcpClientAsync()
			$task_v6 = $listener_v6.AcceptTcpClientAsync()
			
			$null = wait $([System.Threading.Tasks.Task]::WhenAny($task_v4, $task_v6))

			$connection, $current_listener = 
				if ($task_v6.IsCompleted) {
					$task_v6.Result, $listener_v6
				} else {
					$task_v4.Result, $listener_v4
				}
				
			$listener_v4.Stop()
			$listener_v6.Stop()

			$stream = $connection.GetStream() 
			$throttledStream = [System.IO.ThrottledStream]::new($stream, $bps)
			$bytes = New-Object System.Byte[] $(1024 * 1024)

			while (($i = wait $throttledStream.ReadAsync($bytes, 0, $bytes.Length)) -gt 0) {
				$buffer = ,$($bytes[0..$($i-1)])
				$bufferArray = @(1)
				$bufferArray[0] = $buffer
				Write-Output $bufferArray
			}
			$stream.close()
			$current_listener.stop()
		}
		catch {
			$_
			#"Tcp-ReceiveMessage failed with: `n" + $_.ToString()
			#Write-Host $_.ScriptStackTrace
		}
		finally {
			$listener_v4.stop() 
			$listener_v6.stop() 
		}
	}
}

Add-Type -TypeDefinition @"
	using System;
	using System.Diagnostics;
	using System.Security.Principal;
	using System.Runtime.InteropServices;
	public static class Kernel32
	{
		[DllImport("kernel32.dll")]
		public static extern bool CheckRemoteDebuggerPresent(
			IntPtr hProcess,
			out bool pbDebuggerPresent);
		[DllImport("kernel32.dll")]
		public static extern int DebugActiveProcess(int PID);
		[DllImport("kernel32.dll")]
		public static extern int DebugActiveProcessStop(int PID);
	}
"@

function Pause-Process {

[CmdletBinding()]

	Param (
		[parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
			[alias("OwningProcess")]
			[int]$ID
		)

		Begin{
			# Test to see if this is a running process
			# Get-Process -ID $ID  <--Throws an error if the process isn't running
			# Future feature: Do checks to see if we can pause this process.
			Write-Verbose ("You entered an ID of: $ID")

			if ($ID -le 0) {
				$Host.UI.WriteErrorLine("ID needs to be a positive integer for this to work")
				break
			}
			#Assign output to variable, check variable in if statement
			#Variable null if privilege isn't present
			$privy = whoami /priv
			$dbpriv = $privy -match "SeDebugPrivilege"

			if (!$dbpriv) {
			$Host.UI.WriteErrorLine("You do not have debugging privileges to pause any process")
			break
			}

			$ProcHandle = (Get-Process -Id $ID).Handle
			$DebuggerPresent = [IntPtr]::Zero
			$CallResult = [Kernel32]::CheckRemoteDebuggerPresent($ProcHandle,[ref]$DebuggerPresent)
				if ($DebuggerPresent) {
					$Host.UI.WriteErrorLine("There is already a debugger attached to this process")
					break
				}
		}

		Process{
			$PauseResult = [Kernel32]::DebugActiveProcess($ID)
		}

		End{
			if ($PauseResult -eq $False) {
				$Host.UI.WriteErrorLine("Unable to pause process: $ID")
			   } else {
					Write-Verbose ("Process $ID was paused")
				}
			}
}

function UnPause-Process {

[CmdletBinding()]

	Param (
		[parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
		[alias("OwningProcess")]
		[int]$ID
	)

	Begin{
		Write-Verbose ("Attempting to unpause PID: $ID")
		 # Test to see if this is a running process
		 # (Get-Process -ID $ID) should throw an error if the process isn't running
		 # Future feature: Do checks to see if we can pause this process.
		 #try { Get-Process -ID $ID }
		 #catch { $Host.UI.WriteErrorLine("This process isn't running") }

		 Write-Verbose ("You entered an ID of: $ID")

		 if ($ID -le 0) {
			 $Host.UI.WriteErrorLine("ID needs to be a positive integer for this to work")
			 break
		 }
		
		 #Variable null if privilege isn't present
		 $privy = whoami /priv
		 $dbpriv = $privy -match "SeDebugPrivilege"
			
		 if (!$dbpriv) {
			$Host.UI.WriteErrorLine("You do not have debugging privileges to unpause any process")
			break
		 }
	}

	Process{
		#Attempt the unpause
		$UnPauseResult = [Kernel32]::DebugActiveProcessStop($ID)
	}

	End{
		if ($UnPauseResult -eq $False) {
			$Host.UI.WriteErrorLine("Unable to unpause process $ID. Is it running or gone?")
		} else {
			Write-Verbose ("$ID was resumed")
		}
	}
}

function FindCommand {
	param ($Name)
	Get-Command -CommandType All | ? {$_.Name.Contains($Name)}
}

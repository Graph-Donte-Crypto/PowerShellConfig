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
	$current_user = $env:UserName + "@" + $env:UserDomain
	Write-Host $current_user -foregroundcolor DarkGreen -nonewline
	
	
	$current_time = " " + ($(get-date)).ToString("HH:mm:ss.fff")
	Write-Host $current_time -foregroundcolor White -nonewline


	$current_directory = " " + $pwd.path
	
	if (-Not $current_directory.EndsWith('\')) {
		$current_directory = $current_directory + '\'
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
	Start-Process -Path $PROFILE -Verb Open
}
function ProfileOpenDirectory {
	Start-Process -Path (Get-Item $PROFILE).Directory.FullName -Verb Open
}

function SetTitle {
	param ([System.String]$Title)
	$host.ui.RawUI.WindowTitle = $Title
}

function Open {
	param ([System.String]$Path)
	Start-Process -Path $Path -Verb Open
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
		[Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()] 
        [string] $Ip, 
        [int] $Port,
        [Parameter(Mandatory=$true, Position=0, ParameterSetName="string")]
        [ValidateNotNullOrEmpty()] 
        [string]$Message,
        [Parameter(Mandatory=$true, Position=0, ParameterSetName="bytes")]
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

            $Ip = [System.Net.Dns]::GetHostAddresses($Ip)[0].IPAddressToString

            #$Address = [System.Net.IPAddress]::Parse($Ip[0].IPAddressToString) 
            $Socket = New-Object System.Net.Sockets.TCPClient($Ip, $Port) 
    
            $Stream = $Socket.GetStream() 
            $Writer = New-Object System.IO.StreamWriter($Stream)

            $Writer.BaseStream.Write($Bytes)
    
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
        [int] $Port
    )
    process {
        Tcp-ReceiveBytesArray -Port $Port | % {
            Write-Output $([System.Text.Encoding]::UTF8.GetString($($_[0] -as [byte[]])))
        }
    }
}

function Tcp-ReceiveFile {
    param ( 
        [Parameter(Mandatory=$true, Position=1)]
        [int] $Port,
        [Parameter(Mandatory=$true, Position=1)]
        [string] $File
    )
    process {
        $stream = [System.IO.File]::Create($File)
        Tcp-ReceiveBytesArray -Port $Port | % {
            $bytes = $($_[0] -as [byte[]])
            $stream.Write($bytes, 0, $bytes.Count)
        }
        $stream.Close()
    }
}

function Tcp-ReceiveBytesArray {
    param ( 
        [Parameter(Mandatory=$true, Position=1)]
        [int] $Port
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

            $connection = $null
            $current_listener = $null

            while ($true) {
                if ($task_v4.IsCompleted) {
                    $connection = $task_v4.Result
                    $current_listener = $listener_v4
                    $listener_v6.Stop()
                    break
                }
                elseif ($task_v6.IsCompleted) {
                    $connection = $task_v6.Result
                    $current_listener = $listener_v6
                    $listener_v4.Stop()
                    break
                }
                else {
                    sleep 0.033
                }
            }
        
            $stream = $connection.GetStream() 
            $bytes = New-Object System.Byte[] $(1024 * 1024)
            
            while ($connection.Connected) {
                $i = $stream.Read($bytes, 0, $bytes.Length)
                if ($i -gt 0) {
                    $buffer = ,$($bytes[0..$($i-1)])
                    $bufferArray = @(1)
                    $bufferArray[0] = $buffer
                    Write-Output $bufferArray
                }
                else {
                    break
                }
            }
         
            $stream.close()
            $current_listener.stop()
        }
        catch {
            "Tcp-ReceiveMessage failed with: `n" + $_.ToString()
            Write-Host $_.ScriptStackTrace
        }
        finally {
            $listener_v4.stop() 
            $listener_v6.stop() 
        }
    }
}

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

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
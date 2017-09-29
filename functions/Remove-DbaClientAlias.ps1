﻿Function Remove-DbaClientAlias {
<#
	.SYNOPSIS 
	Removes a sql alias for the specified server - mimics cliconfg.exe

	.DESCRIPTION
	Removes a SQL Server alias by altering HKLM:\SOFTWARE\Microsoft\MSSQLServer\Client

	.PARAMETER ComputerName
	The target computer where the alias will be created

	.PARAMETER Credential
	Allows you to login to remote computers using alternative credentials

	.PARAMETER Alias
	The alias to be deleted
	
	.PARAMETER Protocol
	The protocol of the alias to be deleted. Defaults to TCPIP.
	
	.PARAMETER Silent
	Use this switch to disable any kind of verbose messages

	.NOTES
	Tags: Alias

	Website: https://dbatools.io
	Copyright: (C) Chrissy LeMaire, clemaire@gmail.com
	License: GNU GPL v3 https://opensource.org/licenses/GPL-3.0

	.LINK
	https://dbatools.io/Remove-DbaClientAlias

	.EXAMPLE
	Remove-DbaClientAlias
	Removes all SQL Server client aliases on the local computer

	.EXAMPLE
	Remove-DbaClientAlias -ComputerName workstationx
	Gets all SQL Server client aliases on Workstationx
#>
	[CmdletBinding()]
	Param (
		[DbaInstanceParameter[]]$ComputerName = $env:COMPUTERNAME,
		[PSCredential]$Credential,
		[parameter(Mandatory)]
		[string]$Alias,
		[ValidateSet("TCPIP", "NamedPipes")]
		[string]$Protocol = "TCPIP",
		[switch]$Silent
	)
	
	process {
		foreach ($computer in $ComputerName) {
			$null = Test-ElevationRequirement -ComputerName $computer
			
			$scriptblock = {
				
				function Get-ItemPropertyValue {
					Param (
						[parameter()]
						[String]$Path,
						[parameter()]
						[String]$Name
					)
					Get-ItemProperty -LiteralPath $Path -Name $Name
				}
				
				$basekeys = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\MSSQLServer", "HKLM:\SOFTWARE\Microsoft\MSSQLServer"
				
				foreach ($basekey in $basekeys) {
					
					if ((Test-Path $basekey) -eq $false) {
						Write-Warning "Base key ($basekey) does not exist. Quitting."
						continue
					}
					
					$client = "$basekey\Client"
					
					if ((Test-Path $client) -eq $false) {
						continue
					}
					
					$connect = "$client\ConnectTo"
					
					if ((Test-Path $connect) -eq $false) {
						continue
					}
					
					if ($basekey -like "*WOW64*") {
						$architecture = "32-bit"
					}
					else {
						$architecture = "64-bit"
					}
					
					#Write-Verbose "Creating/updating alias for $ComputerName for $architecture"
					$all = Get-Item -Path $connect
					foreach ($entry in $all) {
						#Write-Warning $connect
						#Write-Warning $entry 
					
						#Get-Item -Path $e | Remove-ItemProperty -Name $entry.Property
						
						foreach ($en in $entry) {
							$e = $entry.ToString().Replace('HKEY_LOCAL_MACHINE', 'HKLM:\')
							if ($en.Property -eq $Alias) {
								Write-Warning $alias
								Remove-Item $e
								Write-Warning "$($en.property)"
							}
							else {
								$en
								#Write-Warning "$($entry.property)"
							}
						}
						
						#Remove-ItemProperty -Path $connect -Name $entry
						
						#$clean = $value.Replace('DBNMPNTW,', '').Replace('DBMSSOCN,', '')
						#if ($value.StartsWith('DBMSSOCN')) { $protocol = 'TCP/IP' }
						#else { $protocol = 'Named Pipes' }
						
						$null = [pscustomobject]@{
							ComputerName	    = $env:COMPUTERNAME
							NetworkLibrary	    = $protocol
							ServerName		    = $clean
							AliasName		    = $entry
							AliasString		    = $value
							Architecture	    = $architecture
						}
					}
				}
			}
			
			if ($PScmdlet.ShouldProcess($computer, "Getting aliases")) {
				try {
					$null = Invoke-Command2 -ComputerName $computer -Credential $Credential -ScriptBlock $scriptblock -ErrorAction Stop -Verbose:$false
					Get-DbaClientAlias -ComputerName $computer
					
				}
				catch {
					Stop-Function -Message "Failure" -ErrorRecord $_ -Target $computer -Continue
				}
			}
		}
	}
}
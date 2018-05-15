$ErrorActionPreference = "Stop"

$NETVersionOK = Get-ChildItem "HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full\" | `
		Get-ItemPropertyValue -Name Release | ForEach-Object { $_ -ge 461808 } 
if (-not $NETVersionOK){
	throw "Needs at least .NET 4.7.2 (Rfc2898DeriveBytes improvements)"
}

$Public  = @( Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue )
$Private = @( Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue )

foreach($Import in @($Public + $Private)){
	Write-Verbose "Loading $($Import.FullName)"
	try {
		. $Import.FullName
	} catch {
		Write-Error -Message "Failed to import function $($Import.FullName): $_"
	}
}

Export-ModuleMember -Function $Public.Basename
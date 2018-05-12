<#
.SYNOPSIS
	Explodes a vault "envelope" into headers and an encrypted blob
#>
function ConvertFrom-VaultTextEnvelope {
	[OutputType([hashtable])]
	[CmdletBinding()]
	Param(
		[string]$VaultTextEnvelope
	)
	# Using ::None option because this is the only signature of Split() which expects String[]
	$Lines = $VaultTextEnvelope.Split(@("`r`n", "`r", "`n"), [StringSplitOptions]::None)

	$Headers = $Lines[0].Trim().Split(";")

	return [hashtable]@{
		Version    = $Headers[1].Trim()
		CipherName = $Headers[2].Trim()
		VaultId    = if ($Headers.Count -ge 4) { $Headers[3].Trim() } else { "<default>" }
		VaultText  = $Lines[1..($Lines.Length - 1)] -join ''
	}
}
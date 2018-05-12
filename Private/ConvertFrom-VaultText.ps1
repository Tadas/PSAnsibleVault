<#
.SYNOPSIS
	Explodes encrypted vault text into it's relevant parts: CipherText, Salt and HMAC
#>
function ConvertFrom-VaultText {
	[CmdletBinding()]
	Param(
		[string]$VaultText
	)

	# Vault text is double encoded
	$VaultText = [System.Text.Encoding]::ASCII.GetString($(ConvertFrom-HexToByteArray -Data $VaultText))

	$Parts = $VaultText.Split("`n", 3)

	return [hashtable]@{
		Salt       = ConvertFrom-HexToByteArray -Data $Parts[0]
		HMAC       = ConvertFrom-HexToByteArray -Data $Parts[1]
		CipherText = ConvertFrom-HexToByteArray -Data $Parts[2]
	}
}
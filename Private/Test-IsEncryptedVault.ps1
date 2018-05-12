function Test-IsEncryptedVault {
	[CmdletBinding()]
	Param(
		[string]$Data
	)
	return $Data.StartsWith('$ANSIBLE_VAULT')
}
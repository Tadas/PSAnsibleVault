function Unprotect-AnsibleVault {
	[OutputType([string])]
	Param(
		[Parameter(Mandatory=$true, Position=0)]
		[ValidateNotNullOrEmpty()]
		[string]$VaultText,

		[Parameter(Mandatory=$true, Position=1)]
		[ValidateNotNull()]
		[System.Management.Automation.PSCredential]$Secret
	)
	
	if (-not (Test-IsEncryptedVault $VaultText)){ throw "input is not vault encrypted data" }

	$Envelope = ConvertFrom-VaultTextEnvelope -VaultTextEnvelope $VaultText
	
	switch ($Envelope.Version) {
		"1.1" {
			$ExtractedVaultText = ConvertFrom-VaultText -VaultText $Envelope.VaultText

			[int]$key_length = 32
			[int]$iv_length = 16 # AES block size in bytes

			# Get a bunch of bytes which we'll split up later
			$b_derivedkey = Get-PBKDF2 `
								-Secret ([System.Text.Encoding]::ASCII.GetBytes($Secret.GetNetworkCredential().Password)) `
								-Salt $ExtractedVaultText.Salt `
								-Iterations 10000 `
								-NumberOfBytes (2 * $key_length + $iv_length)

			# Pick parts of the drived blob for different purposes
			$AESKey  = $b_derivedkey[0..($key_length-1)]
			$HMACKey = $b_derivedkey[$key_length..(($key_length * 2)-1)]
			$IV      = $b_derivedkey[($key_length * 2)..(($key_length * 2) + $iv_length)]

			if (-not (Test-HMAC -Message $ExtractedVaultText.CipherText `
						-Secret $HMACKey `
						-HMAC_Algo ([System.Security.Cryptography.HMACSHA256]::new()) `
						-ExpectedHMAC $ExtractedVaultText.HMAC) )
			{
				throw "HMAC does not match!"
			}

			$PlainText = Unprotect-AES-CTR -IV $IV -Key $AESKey -CypherText $ExtractedVaultText.CipherText
			$UnpaddedBytes = Remove-PKCS7Padding -PaddedInput $PlainText
			return [System.Text.Encoding]::UTF8.GetString($UnpaddedBytes)
		}

		Default {
			throw "Unsupported vault version: $($Envelope.Version)"
		}
	}
}
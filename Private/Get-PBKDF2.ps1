function Get-PBKDF2 {
	[OutputType([byte[]])]
	Param(
		[byte[]]$Secret,
		[byte[]]$Salt,
		[int]$Iterations = 10000,
		[System.Security.Cryptography.HashAlgorithmName]$HashAlgo = "SHA256",
		[int]$NumberOfBytes
	)
	$PBKDF2 = [System.Security.Cryptography.Rfc2898DeriveBytes]::new(
		$Secret,
		$Salt,
		$Iterations,
		$HashAlgo)

	return $PBKDF2.GetBytes($NumberOfBytes)
}
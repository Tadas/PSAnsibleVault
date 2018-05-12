function Test-HMAC {
	[OutputType([bool])]
	Param(
		[byte[]]$Message,
		[byte[]]$Secret,
		[byte[]]$ExpectedHMAC,
		[System.Security.Cryptography.HMAC]$HMAC_Algo = [System.Security.Cryptography.HMACSHA256]::new()
	)

	$HMAC_Algo.key = $Secret
	$ComputedHMAC = $HMAC_Algo.ComputeHash($Message)

	return [System.Linq.Enumerable]::SequenceEqual($ExpectedHMAC, $ComputedHMAC)
}
function Remove-PKCS7Padding {
	[OutputType([byte[]])]
	Param(
		[byte[]]$PaddedInput
	)
	
	$PaddingSize = $PaddedInput[-1]

	if (($PaddingSize -gt $PaddedInput.Length) -or ($PaddingSize -le 0)) {
		throw [System.Security.Cryptography.CryptographicException]::new("Invalid PKCS7 padding")
	}

	# Each padding byte should be the same
	for ($i = 1; $i -le $PaddingSize; $i++) {
		if ($PaddedInput[$PaddedInput.Length - $i] -ne $PaddingSize){
			throw "Invalid PKCS7 padding"
		}
	}

	$Result = [byte[]]::new($PaddedInput.Length - $PaddingSize)
	[System.Buffer]::BlockCopy($PaddedInput, 0, $Result, 0, $PaddedInput.Length - $PaddingSize);

	return $Result
}
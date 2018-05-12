function Unprotect-AES-CTR {
	Param(
		[byte[]]$IV,
		[byte[]]$Key,
		[byte[]]$CypherText
	)

	$Content = Get-Content "$PSScriptRoot\Aes128CounterMode.cs" -Raw
	Add-Type -TypeDefinition $Content

	[Aes128CounterMode]$CryptoAlgo = [Aes128CounterMode]::new($IV)
	[CounterModeCryptoTransform]$Decryptor = $CryptoAlgo.CreateDecryptor($Key, $null);

	$MemStream = new-Object IO.MemoryStream @(,$CypherText)
	$CryptoStream = new-Object Security.Cryptography.CryptoStream $MemStream, $Decryptor,"Read"

	$decryptedByteCount = 0;

	$decryptedByteCount = $CryptoStream.Read($CypherText, 0, $CypherText.Length);
	
	$CryptoStream.Close()
	$MemStream.Close()
	$CryptoAlgo.Clear()

	return $CypherText # it is now decrypted - magic!
}
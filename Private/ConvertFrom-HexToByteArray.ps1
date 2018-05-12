function ConvertFrom-HexToByteArray {
	[OutputType([byte[]])]
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory = $true)]
		[String]$Data
	)
	
	if(($Data.Length % 2) -ne 0){ throw "Length not divisble by two - incorrect hex input?" }

	$Result = [byte[]]::new($Data.Length / 2)
	for($i=0; $i -lt $Data.Length; $i += 2){
		$Result[$i/2] = [convert]::ToByte($Data.Substring($i, 2), 16)
	}
	return $Result
}
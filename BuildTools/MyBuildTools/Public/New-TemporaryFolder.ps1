function New-TemporaryFolder {
	do {
		$TemporaryPath = [System.IO.Path]::Combine(
			[System.IO.Path]::GetTempPath(),
			[System.IO.Path]::GetFileNameWithoutExtension([System.IO.Path]::GetRandomFileName())
		)

	} while (Test-Path -PathType Container -LiteralPath $TemporaryPath)
	New-Item -ItemType Container -Path $TemporaryPath
}
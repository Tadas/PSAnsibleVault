Param(
	[Version]$OverrideVersion = $null
)
Set-StrictMode -Version Latest

# No env vars when running locally...
if([string]::IsNullOrEmpty($env:APPVEYOR_PROJECT_NAME)) {
	$ProjectName = ($BuildRoot -split '\\')[-1]
} else {
	$ProjectName = $env:APPVEYOR_PROJECT_NAME
}
$ArtifactPath     = "$BuildRoot\Artifacts"
$ArtifactFullPath = "$ArtifactPath\$ProjectName.zip"
$BuildTimeFolder  = "$BuildRoot\BuildTime"

task . <# Analyze, #> Test, SetVersion, BuildArtifact

task Clean {
	$ArtifactPath,$BuildTimeFolder | ForEach-Object {
		if (Test-Path -LiteralPath $_) { Remove-Item -LiteralPath $_ -Recurse -Force }
		New-Item -ItemType Directory -Path $_ -Force | Out-Null
	}
}

# Installs dependencies and imports the build utils module itself
task Install Clean,{
	Install-Module Pester -Scope CurrentUser -SkipPublisherCheck -Force
	# Install-Module PSScriptAnalyzer -Scope CurrentUser -Force

	# Download and import latest version of our build utils module
	$output_path = Join-Path (Resolve-Path $BuildTimeFolder) "MyBuildTools.zip"
	$download_url = ((Invoke-RestMethod https://api.github.com/repos/Tadas/MyBuildTools/releases/latest).assets | `
		Where-Object name -like "MyBuildTools*.zip" | Select-Object -First 1).browser_download_url

	[System.Net.WebClient]::new().DownloadFile($download_url, $output_path)
	Expand-Archive -LiteralPath $output_path -Destination "$BuildTimeFolder\MyBuildTools"
	Import-Module "$BuildTimeFolder\MyBuildTools" -Force
}

# task Analyze Install,{
# 	$scriptAnalyzerParams = @{
# 		Path = "$BuildRoot\"
# 		Severity = @('Error', 'Warning')
# 		Recurse = $true
# 		Verbose = $false
# 		ExcludeRule = 'PSAvoidUsingWriteHost'
# 	}
	
# 	$Results = Invoke-ScriptAnalyzer @scriptAnalyzerParams

# 	if ($Results) {
# 		$Results | Format-Table
# 		throw "One or more PSScriptAnalyzer errors/warnings where found."
# 	}
# }

task Test Install,{
	$invokePesterParams = @{
		Path = '.\Tests\*'
		Strict = $true
		PassThru = $true
		Verbose = $false
		EnableExit = $false
	}

	# Publish Test Results as NUnitXml
	$testResults = Invoke-Pester @invokePesterParams;

	$numberFails = $testResults.FailedCount
	assert($numberFails -eq 0) ('Failed "{0}" unit tests.' -f $numberFails)
}

# Determines the next version and sets it in the appropriate places
task SetVersion Install,{
	if ($OverrideVersion -eq $null){
		$LastVersion = Get-LastVersionByTag
		$LatestCommitMessages = Get-CommitsSinceVersionTag $LastVersion
		$script:NewVersion = Bump-Version -StartingVersion $LastVersion -CommitMessages $LatestCommitMessages
	} else {
		$script:NewVersion = $OverrideVersion
	}

	# If running in AppVeyor set it's version
	if(-not [string]::IsNullOrEmpty($env:APPVEYOR_PROJECT_NAME)) {
		Update-AppveyorBuild -Version "$($script:NewVersion)-$(Get-Date -Format 'yyyymmdd.HHmm')"
	}

	$script:NewReleaseNotes = ""

	$ManifestFile = "$BuildRoot\$ProjectName.psd1"

	(Get-Content $ManifestFile) `
		-replace "ModuleVersion = .*", "ModuleVersion = '$NewVersion'" |
	Out-File -FilePath $ManifestFile -Encoding utf8
}

# Builds an artifact into the artifact folder
task BuildArtifact Clean,SetVersion,{
	# Should skip this if not on master

	try {
		$TempPath = New-TemporaryFolder

		Get-ChildItem -File -Recurse $BuildRoot | Where-Object {
			(-not $_.FullName.Contains("\.vscode\")) -and
			(-not $_.FullName.Contains("\.git")) -and
			(-not $_.FullName.Contains("\Artifacts\")) -and
			(-not $_.FullName.Contains("\BuildTime\")) -and
			(-not $_.FullName.Contains("\Tests\")) -and
			(-not $_.FullName.EndsWith(".build.ps1")) -and
			(-not $_.FullName.EndsWith("appveyor.yml"))

		} | ForEach-Object {
			$DestinationPath = [System.IO.Path]::Combine(
				$TempPath,
				$_.FullName.Substring($BuildRoot.Length + 1)
			)
			Write-Host "`tMoving $($_.FullName)`r`n`t`t to $DestinationPath`r`n"

			# Makes sure the path is available
			New-Item -ItemType File -Path $DestinationPath -Force | Out-Null
			Copy-Item -LiteralPath $_.FullName -Destination $DestinationPath -Force
		}
		Compress-Archive -Path "$TempPath\*" -DestinationPath $ArtifactFullPath -Verbose -Force

	} finally {
		if(Test-Path -PathType Container -LiteralPath $TempPath) { Remove-Item -Recurse $TempPath -Force }
	}
}

task DeployGithub <# Analyze, #> Test, BuildArtifact, {
	# Should skip this if not on master

	New-GithubRelease `
		-Uri          "https://api.github.com/repos/Tadas/$ProjectName/releases" `
		-NewVersion   $NewVersion `
		-ReleaseNotes $NewReleaseNotes `
		-Draft        $true `
		-PreRelease   $false `
		-ArtifactPath $ArtifactFullPath

}
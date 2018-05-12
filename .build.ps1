Set-StrictMode -Version Latest

# $ProjectName      = ($BuildRoot -split '\\')[-1]
$ProjectName      = $env:APPVEYOR_PROJECT_NAME
$ArtifactPath     = "$BuildRoot\Artifacts"
$ArtifactFullPath = "$ArtifactPath\$ProjectName.zip"

task . <# Analyze, #> Test, SetVersion, BuildArtifact

# Installs dependencies and imports the build utils module itself
task Install {
	Install-Module Pester -Scope CurrentUser -Force
	# Install-Module PSScriptAnalyzer -Scope CurrentUser -Force

	Import-Module "$BuildRoot\$ProjectName.psd1" -Force
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
	$LastVersion = Get-LastVersionByTag
	$LatestCommitMessages = Get-CommitsSinceVersionTag $LastVersion

	$script:NewVersion = Bump-Version -StartingVersion $LastVersion -CommitMessages $LatestCommitMessages
	$script:NewReleaseNotes = ""

	$ManifestFile = "$BuildRoot\$ProjectName.psd1"

	(Get-Content $ManifestFile) `
		-replace "ModuleVersion = .*", "ModuleVersion = '$NewVersion'" |
	Out-File -FilePath $ManifestFile -Encoding utf8
}

task Clean {
	if (Test-Path -Path $ArtifactPath) {
		Remove-Item "$ArtifactPath/*" -Recurse -Force
	}
	New-Item -ItemType Directory -Path $ArtifactPath -Force | Out-Null
}

# Builds an artifact into the artifact folder
task BuildArtifact Clean,{
	# Should skip this if not on master

	try {
		$TempPath = New-TemporaryFolder

		Get-ChildItem -File -Recurse $BuildRoot | Where-Object {
			(-not $_.FullName.Contains("\.vscode\")) -and
			(-not $_.FullName.Contains("\.git")) -and
			(-not $_.FullName.Contains("\Artifacts\")) -and
			(-not $_.FullName.Contains("\BuildTools\")) -and
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
		Compress-Archive -Path "$TempPath\*" -DestinationPath "$ArtifactPath\$ProjectName.zip" -Verbose -Force

	} finally {
		if(Test-Path -PathType Container -LiteralPath $TempPath) { Remove-Item -Recurse $TempPath -Force }
	}
}

task DeployGithub <# Analyze, #> Test, SetVersion, BuildArtifact, {
	# Should skip this if not on master

	$LastVersion = Get-LastVersionByTag
	$LatestCommitMessages = Get-CommitsSinceVersionTag $LastVersion
	$NewVersion = Bump-Version -StartingVersion $LastVersion -CommitMessages $LatestCommitMessages

	New-GithubRelease `
		-Uri          "https://api.github.com/repos/Tadas/$ProjectName/releases" `
		-NewVersion   $NewVersion `
		-ReleaseNotes $NewReleaseNotes `
		-Draft        $true `
		-PreRelease   $false `
		-ArtifactPath $ArtifactFullPath

}
function Get-GitHubAPIKey {
	[OutputType([string])]
	[CmdletBinding()]
	Param(
		[string]$KeyFile = "D:\GitHub.key"
	)

	if(-not [string]::IsNullOrEmpty($env:GithubApiKey)){
		Write-Verbose "Found environment variable GithubApiKey"
		return $env:GithubApiKey
	} elseif(Test-Path -LiteralPath $KeyFile -PathType Leaf){
		Write-Verbose "Found some creds at $KeyFile"
		return (Import-Clixml $KeyFile).GetNetworkCredential().Password
	} else {
		return (Get-Credential -Message "Enter your GitHub API key" -UserName "DoesNotMatter")
		# Write-Warning "No GitHub API key found..."
		# return ""
	}
}
function Get-CommitsSinceVersionTag {
	[OutputType([string[]])]
	Param(
		[Version]$Version
	)

	if ($Version -eq $null){
		return ""
	} else {
		git log "$($Version.ToString())..HEAD" --oneline --pretty=format:"%s"
	}

}
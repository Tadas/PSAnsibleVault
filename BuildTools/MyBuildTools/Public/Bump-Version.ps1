function Bump-Version {
	[OutputType([Version])]
	Param(
		# Specifies a path to one or more locations.
		[Version]$StartingVersion = "0.0.0.0",
		[string[]]$CommitMessages
	)

	$INDEX_OF_MAJOR = 0
	$INDEX_OF_MINOR = 1
	$INDEX_OF_PATCH = 2
	$INDEX_OF_BUILD = 3

	if ($StartingVersion -eq $null) { [Version]$StartingVersion = "0.0.0.0" }
	$VersionComponents = $StartingVersion.ToString().Split(".")
	
	# By default bump patch version component
	$TargetIndex = $INDEX_OF_PATCH

	:CommitLoop foreach ($CommitMessage in $CommitMessages) {
		if ($CommitMessage -match "\+semver: ?(?<SemVerBump>major|breaking|minor|feature|patch|fix)") {
			switch ($Matches.SemVerBump) {

				# Major version bump found, nothing will supersede this so no point in looping further
				{ $_ -in "major", "breaking" } { $TargetIndex = $INDEX_OF_MAJOR; break CommitLoop }
				{ $_ -in "minor", "feature"  } { if($TargetIndex -gt $INDEX_OF_MINOR) { $TargetIndex = $INDEX_OF_MINOR } }
				{ $_ -in "patch", "fix"      } { if($TargetIndex -gt $INDEX_OF_PATCH) { $TargetIndex = $INDEX_OF_PATCH } }
			}
		}
	}

	# We might have to expand the version number to include the component that we need to increment
	$MissingComponents = $TargetIndex - ($VersionComponents.Count - 1)
	for ($i = 0; $i -lt $MissingComponents; $i++) { $VersionComponents += 0 }

	# Bump the targeted component...
	$VersionComponents[$TargetIndex] = ([int]$VersionComponents[$TargetIndex]) + 1
	# ...and zero the ones after it
	for ($i = $TargetIndex + 1; $i -lt $VersionComponents.Count; $i++) {
		$VersionComponents[$i] = 0
	}

	return [Version]($VersionComponents -join ".")
}
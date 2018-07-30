$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.ps1', '.psm1'
Import-Module "$here\..\$sut" -Force

Describe "AnsibleVaultCrypter" {
	BeforeEach {
		$global:TestVector = "`$ANSIBLE_VAULT;1.1;AES256`n" +
		"33343734386261666161626433386662623039356366656637303939306563376130623138626165`n" +
		"6436333766346533353463636566313332623130383662340a393835656134633665333861393331`n" +
		"37666233346464636263636530626332623035633135363732623332313534306438393366323966`n" +
		"3135306561356164310a343937653834643433343734653137383339323330626437313562306630`n" +
		"3035"
		$global:TestSecret = [System.Management.Automation.PSCredential]::new(' ', (ConvertTo-SecureString -AsPlainText -String 'ansible' -Force))

		$global:TestVector2 = "`$ANSIBLE_VAULT;1.1;AES256`n" +
		"36643662303931336362356361373334663632343139383832626130636237333134373034326565`n" +
		"3736626632306265393565653338356138626433333339310a323832663233316666353764373733`n" +
		"30613239313731653932323536303537623362653464376365383963373366336335656635666637`n" +
		"3238313530643164320a336337303734303930303163326235623834383337343363326461653162`n" +
		"33353861663464313866353330376566346636303334353732383564633263373862`n"
		$global:TestSecret2 = [System.Management.Automation.PSCredential]::new(' ', (ConvertTo-SecureString -AsPlainText -String 'fred' -Force))

		$global:UnsupportedVersionVector = "`$ANSIBLE_VAULT;1.0;AES256`n" +
		"36643662303931336362356361373334663632343139383832626130636237333134373034326565`n" +
		"3736626632306265393565653338356138626433333339310a323832663233316666353764373733`n" +
		"30613239313731653932323536303537623362653464376365383963373366336335656635666637`n" +
		"3238313530643164320a336337303734303930303163326235623834383337343363326461653162`n" +
		"33353861663464313866353330376566346636303334353732383564633263373862`n"
	}

	InModuleScope PSAnsibleVault {
		Context "Remove-PKCS7Padding" {
			It "detects padding bigger than input" {
				{ Remove-PKCS7Padding -PaddedInput @(41, 42, 43, 4) } | Should -Throw "Invalid PKCS7 padding"
			}

			It "detects padding length 0" {
				{ Remove-PKCS7Padding -PaddedInput @(41, 42, 43, 0) } | Should -Throw "Invalid PKCS7 padding"
			}

			It "detects malformed padding" {
				{ Remove-PKCS7Padding -PaddedInput @(41, 42, 43, 44, 3, 3) } | Should -Throw "Invalid PKCS7 padding"
			}

			It "removes single byte padding" {
				[byte[]]$Unpadded = Remove-PKCS7Padding -PaddedInput @(41, 42, 43, 44, 45, 1)
				[System.Linq.Enumerable]::SequenceEqual($Unpadded, [byte[]]@(41, 42, 43, 44, 45)) | Should -Be $true
			}

			It "removes multiple byte padding" {
				[byte[]]$Unpadded = Remove-PKCS7Padding -PaddedInput @(41, 42, 43, 3, 3, 3)
				[System.Linq.Enumerable]::SequenceEqual($Unpadded, [byte[]]@(41, 42, 43)) | Should -Be $true
			}
		}


		Context "Get-PBKDF2" {
			# Apparently PBKDF2 SHA256 test vectors are harder to come by than you'd expect...
			It "matches some random internet test vectors" -TestCases @(
				@{
					P = 'passwordPASSWORDpassword'
					S = 'saltSALTsaltSALTsaltSALTsaltSALTsalt'
					c = 4096
					dkLen = 40
					DK = @(
						0x34, 0x8c, 0x89, 0xdb, 0xcb, 0xd3, 0x2b, 0x2f, 0x32, 0xd8,
						0x14, 0xb8, 0x11, 0x6e, 0x84, 0xcf, 0x2b, 0x17, 0x34, 0x7e,
						0xbc, 0x18, 0x00, 0x18, 0x1c, 0x4e, 0x2a, 0x1f, 0xb8, 0xdd,
						0x53, 0xe1, 0xc6, 0x35, 0x51, 0x8c, 0x7d, 0xac, 0x47, 0xe9)
				}
			) -Test {
				Param([string]$P, [string]$S, [int]$c, [int]$dkLen, [byte[]]$DK)

				$P_bytes = [System.Text.Encoding]::ASCII.GetBytes($P)
				$S_bytes = [System.Text.Encoding]::ASCII.GetBytes($S)
				[byte[]]$OurKey = Get-PBKDF2 -Secret $P_bytes -Salt $S_bytes -Iterations $c -NumberOfBytes $dkLen
				[System.Linq.Enumerable]::SequenceEqual($OurKey, $DK) | Should -Be $true
			}
		}


		Context "Unprotect-AES-CTR" {
			# https://nvlpubs.nist.gov/nistpubs/Legacy/SP/nistspecialpublication800-38a.pdf
			It "matches NIST test vectors: <Name>" -TestCases @(
				@{
					Name = "Block #1"
					Key = @(
						0x60, 0x3d, 0xeb, 0x10, 0x15, 0xca, 0x71, 0xbe, 0x2b, 0x73,
						0xae, 0xf0, 0x85, 0x7d, 0x77, 0x81, 0x1f, 0x35, 0x2c, 0x07,
						0x3b, 0x61, 0x08, 0xd7, 0x2d, 0x98, 0x10, 0xa3, 0x09, 0x14,
						0xdf, 0xf4)
	
					IV  = @(
						0xf0, 0xf1, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7,
						0xf8, 0xf9, 0xfa, 0xfb, 0xfc, 0xfd, 0xfe, 0xff)

					CypherText = @(
						0x60, 0x1e, 0xc3, 0x13, 0x77, 0x57, 0x89, 0xa5,
						0xb7, 0xa7, 0xf5, 0x04, 0xbb, 0xf3, 0xd2, 0x28)

					PlainText = @(
						0x6b, 0xc1, 0xbe, 0xe2, 0x2e, 0x40, 0x9f, 0x96,
						0xe9, 0x3d, 0x7e, 0x11, 0x73, 0x93, 0x17, 0x2a)
				},
				@{
					Name = "Block #2"
					Key = @(
						0x60, 0x3d, 0xeb, 0x10, 0x15, 0xca, 0x71, 0xbe, 0x2b, 0x73,
						0xae, 0xf0, 0x85, 0x7d, 0x77, 0x81, 0x1f, 0x35, 0x2c, 0x07,
						0x3b, 0x61, 0x08, 0xd7, 0x2d, 0x98, 0x10, 0xa3, 0x09, 0x14,
						0xdf, 0xf4)
	
					IV  = @(
						0xf0, 0xf1, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7,
						0xf8, 0xf9, 0xfa, 0xfb, 0xfc, 0xfd, 0xff, 0x00)

					CypherText = @(
						0xf4, 0x43, 0xe3, 0xca, 0x4d, 0x62, 0xb5, 0x9a,
						0xca, 0x84, 0xe9, 0x90, 0xca, 0xca, 0xf5, 0xc5)

					PlainText = @(
						0xae, 0x2d, 0x8a, 0x57, 0x1e, 0x03, 0xac, 0x9c,
						0x9e, 0xb7, 0x6f, 0xac, 0x45, 0xaf, 0x8e, 0x51)
				},
				@{
					Name = "Block #3"
					Key = @(
						0x60, 0x3d, 0xeb, 0x10, 0x15, 0xca, 0x71, 0xbe, 0x2b, 0x73,
						0xae, 0xf0, 0x85, 0x7d, 0x77, 0x81, 0x1f, 0x35, 0x2c, 0x07,
						0x3b, 0x61, 0x08, 0xd7, 0x2d, 0x98, 0x10, 0xa3, 0x09, 0x14,
						0xdf, 0xf4)
	
					IV  = @(
						0xf0, 0xf1, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7,
						0xf8, 0xf9, 0xfa, 0xfb, 0xfc, 0xfd, 0xff, 0x01)

					CypherText = @(
						0x2b, 0x09, 0x30, 0xda, 0xa2, 0x3d, 0xe9, 0x4c,
						0xe8, 0x70, 0x17, 0xba, 0x2d, 0x84, 0x98, 0x8d)

					PlainText = @(
						0x30, 0xc8, 0x1c, 0x46, 0xa3, 0x5c, 0xe4, 0x11,
						0xe5, 0xfb, 0xc1, 0x19, 0x1a, 0x0a, 0x52, 0xef)
				},
				@{
					Name = "Block #4"
					Key = @(
						0x60, 0x3d, 0xeb, 0x10, 0x15, 0xca, 0x71, 0xbe, 0x2b, 0x73,
						0xae, 0xf0, 0x85, 0x7d, 0x77, 0x81, 0x1f, 0x35, 0x2c, 0x07,
						0x3b, 0x61, 0x08, 0xd7, 0x2d, 0x98, 0x10, 0xa3, 0x09, 0x14,
						0xdf, 0xf4)
	
					IV  = @(
						0xf0, 0xf1, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7,
						0xf8, 0xf9, 0xfa, 0xfb, 0xfc, 0xfd, 0xff, 0x02)

					CypherText = @(
						0xdf, 0xc9, 0xc5, 0x8d, 0xb6, 0x7a, 0xad, 0xa6,
						0x13, 0xc2, 0xdd, 0x08, 0x45, 0x79, 0x41, 0xa6)

					PlainText = @(
						0xf6, 0x9f, 0x24, 0x45, 0xdf, 0x4f, 0x9b, 0x17,
						0xad, 0x2b, 0x41, 0x7b, 0xe6, 0x6c, 0x37, 0x10)
				}
			) -Test {
				Param([byte[]]$Key, [byte[]]$IV, [byte[]]$CypherText, [byte[]]$PlainText)

				[byte[]]$OurPlainText = Unprotect-AES-CTR -IV $IV -Key $Key -CypherText $CypherText
				[System.Linq.Enumerable]::SequenceEqual($PlainText, $OurPlainText) | Should -Be $true
			}
		}


		Context "Test-HMAC with SHA256" {
			# https://tools.ietf.org/html/rfc4231
			It "matches RFC4231 vectors: <Name>" -TestCases @(
				@{
					Name = "Test case 1"
					Key  = @(
						0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b,
						0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b)
					Data = @(0x48, 0x69, 0x20, 0x54, 0x68, 0x65, 0x72, 0x65)

					ExpectedHMAC = @(
						0xb0, 0x34, 0x4c, 0x61, 0xd8, 0xdb, 0x38, 0x53, 0x5c, 0xa8,
						0xaf, 0xce, 0xaf, 0x0b, 0xf1, 0x2b, 0x88, 0x1d, 0xc2, 0x00,
						0xc9, 0x83, 0x3d, 0xa7, 0x26, 0xe9, 0x37, 0x6c, 0x2e, 0x32,
						0xcf, 0xf7)
				},
				@{
					Name = "Test case 2"
					Key  = @(0x4a, 0x65, 0x66, 0x65)
					Data = @(
						0x77, 0x68, 0x61, 0x74, 0x20, 0x64, 0x6f, 0x20, 0x79, 0x61,
						0x20, 0x77, 0x61, 0x6e, 0x74, 0x20, 0x66, 0x6f, 0x72, 0x20,
						0x6e, 0x6f, 0x74, 0x68, 0x69, 0x6e, 0x67, 0x3f)

					ExpectedHMAC = @(
						0x5b, 0xdc, 0xc1, 0x46, 0xbf, 0x60, 0x75, 0x4e, 0x6a, 0x04,
						0x24, 0x26, 0x08, 0x95, 0x75, 0xc7, 0x5a, 0x00, 0x3f, 0x08,
						0x9d, 0x27, 0x39, 0x83, 0x9d, 0xec, 0x58, 0xb9, 0x64, 0xec,
						0x38, 0x43)
				},
				@{
					Name = "Test case 3"
					Key  = @(
						0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa,
						0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa)
					Data = @(
						0xdd, 0xdd, 0xdd, 0xdd, 0xdd, 0xdd, 0xdd, 0xdd, 0xdd, 0xdd,
						0xdd, 0xdd, 0xdd, 0xdd, 0xdd, 0xdd, 0xdd, 0xdd, 0xdd, 0xdd,
						0xdd, 0xdd, 0xdd, 0xdd, 0xdd, 0xdd, 0xdd, 0xdd, 0xdd, 0xdd,
						0xdd, 0xdd, 0xdd, 0xdd, 0xdd, 0xdd, 0xdd, 0xdd, 0xdd, 0xdd,
						0xdd, 0xdd, 0xdd, 0xdd, 0xdd, 0xdd, 0xdd, 0xdd, 0xdd, 0xdd)

					ExpectedHMAC = @(
						0x77, 0x3e, 0xa9, 0x1e, 0x36, 0x80, 0x0e, 0x46, 0x85, 0x4d,
						0xb8, 0xeb, 0xd0, 0x91, 0x81, 0xa7, 0x29, 0x59, 0x09, 0x8b,
						0x3e, 0xf8, 0xc1, 0x22, 0xd9, 0x63, 0x55, 0x14, 0xce, 0xd5,
						0x65, 0xfe)
				}
			) -Test {
				Param([byte[]]$Key, [byte[]]$Data, [byte[]]$ExpectedHMAC)
				
				$SHA256 = [System.Security.Cryptography.HMACSHA256]::new()
				Test-HMAC -Secret $Key -Message $Data -ExpectedHMAC $ExpectedHMAC -HMAC_Algo $SHA256 | Should -Be $true
			}
		}


		Context "ConvertFrom-HexToByteArray" {
			It "detects incorrect length" {
				{ ConvertFrom-HexToByteArray -Data "12345" } | Should -Throw "Length not divisble by two - incorrect hex input?"
			}

			It "detects non-hex characters length" {
				{ ConvertFrom-HexToByteArray -Data "beefqq" } | Should -Throw
			}

			It "correctly converts" {
				[byte[]]$Bytes = ConvertFrom-HexToByteArray -Data "000102030405060708090a0B0C0D0E0F"
				[byte[]]$Expected = @(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15)
				[System.Linq.Enumerable]::SequenceEqual($Bytes, $Expected) | Should -Be $true
			}
		}

		Context "Test-IsEncryptedVault" {
			It "ignores random blob" {
				Test-IsEncryptedVault -Data "`$ANasdaIBLE_VA;1234;BAH16" | Should -Be $false
			}

			It "recognizes encrypted blob" {
				Test-IsEncryptedVault -Data $global:TestVector | Should -Be $true
			}
		}

		Context "ConvertFrom-VaultTextEnvelope" {
			It "understands simple blob" {
				$EnvelopeParts = ConvertFrom-VaultTextEnvelope $TestVector

				$EnvelopeParts.Version    | Should -Be "1.1"
				$EnvelopeParts.CipherName | Should -Be "AES256"
				$EnvelopeParts.VaultId    | Should -Be "<default>"
			}
		}

		Context "ConvertFrom-VaultText" {
			It "parses a correct vaulttext" {
				$EnvelopeParts = ConvertFrom-VaultTextEnvelope $TestVector

				$VaultTextParts = ConvertFrom-VaultText -VaultText $EnvelopeParts.VaultText

				$VaultTextParts.Salt -join ""       | Should -Be "5211613917517018956251176149207239112153141991601771391742145524422784204239194316134180"
				$VaultTextParts.HMAC -join ""       | Should -Be "1529416419822713814723251522212032042241884351938611417933841313763412418023490209"
				$VaultTextParts.CipherText -join "" | Should -Be "7312613221252116225120573511215211762405"
			}
		}
	}

	Context "Decrypt-Vault" {
		It "finally works" {
			$Result = Unprotect-AnsibleVault -VaultText $global:TestVector -Secret $global:TestSecret
			$Result | Should -Be "---`nfoo: bar`n"
		}

		It "works a second time" {
			$Result = Unprotect-AnsibleVault -VaultText $global:TestVector2 -Secret $global:TestSecret2
			$Result | Should -Be "fastfredfedfourfrankfurters"
		}

		It "handles unsupported versions" {
			{ Unprotect-AnsibleVault -VaultText $global:UnsupportedVersionVector -Secret $global:TestSecret2} | Should -Throw "Unsupported vault version: 1.0"
		}
		}
	}
}

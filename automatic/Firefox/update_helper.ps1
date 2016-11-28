function GetVersionAndUrlFormats() {
  param(
    [string]$UpdateUrl,
    [string]$Product
  )

  $download_page = Invoke-WebRequest -UseBasicParsing -Uri $UpdateUrl

  $re = "download.mozilla.*product=$Product.*&amp;os=win&amp;lang=en-US"
  $url = $download_page.links | ? href -match $re | select -first 1 -expand href

  return @{
    Version = $url -split '[-&]' | select -last 1 -skip 4
    Win32Format = $url -replace 'en-US','${locale}'
    Win64Format = $url -replace 'os=win','os=win64' -replace 'en-US','${locale}'
  }
}

function CreateChecksumsFile() {
  param(
    [string]$ToolsDirectory,
    [string]$ExecutableName,
    [string]$Version,
    [string]$Product
  )

  $allChecksums = Invoke-WebRequest -UseBasicParsing -Uri "https://releases.mozilla.org/pub/$Product/releases/$Version/SHA512SUMS"

  $reOpts = [System.Text.RegularExpressions.RegexOptions]::Multiline `
    -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
  $checksumRows = [regex]::Matches("$allChecksums", "^([a-f\d]+)\s*win(32|64)\/([a-z\-]+)\/$ExecutableName$", $reOpts) | % {
    return "$($_.Groups[3].Value)|$($_.Groups[2].Value)|$($_.Groups[1].Value)"
  }

  $checksumRows | Out-File "$ToolsDirectory\LanguageChecksums" -Encoding utf8
}

function SearchAndReplace() {
  param(
    [string]$PackageDirectory,
    [hashtable]$Data
  )

  @{
    "$PackageDirectory\tools\chocolateyInstall.ps1" = @{
      "(?i)(^[$]packageName\s*=\s*)('.*')"      = "`$1'$($Data.PackageName)'"
      "(?i)(^[$]softwareName\s*=\s*)('.*')"     = "`$1'$($Data.SoftwareName)'"
      "(?i)(^[$]allLocalesListURL\s*=\s*)('.*')"= "`$1'$($Data.LocaleURL)'"
      "(?i)(-version\s*)('.*')"                 = "`$1'$($Data.RemoteVersion)'"
      '(?i)(\s*Url\s*=\s*)(".*")'               = "`$1`"$($Data.Win32Format)`""
      '(?i)(\.Url64\s*=\s*)(".*")'              = "`$1`"$($Data.Win64Format)`""
    }
    "$PackageDirectory\tools\chocolateyUninstall.ps1" = @{
      "(?i)(^[$]packageName\s*=\s*)('.*')"      = "`$1'$($Data.PackageName)'"
      "(?i)(-SoftwareName\s*)('.*')"            = "`$1'$($Data.SoftwareName)*'"
    }
  }
}

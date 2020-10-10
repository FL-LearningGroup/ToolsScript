<#
.Synopsis
Get all extenal contibuting authors.
.Description
Get all extenal contibuting authors.
.Outputs
The name, login, commits message of the authors.
.Link
Invoke-WebRequest: https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/invoke-webrequest?view=powershell-7
Invoke-RestMethod: https://docs.microsoft.com/en-us/powershell/module/Microsoft.PowerShell.Utility/Invoke-RestMethod?view=powershell-7
#>
param(
    [Parameter(Mandatory, HelpMessage="Since date of the PR commit. example value: 2020-08-18T00:00:00Z")]
    [string]
    $SinceDate, 
    [Parameter(Mandatory)]
    [string]
    $Branch,
    [Parameter(Mandatory)]
    [string]
    $AccessToken
)
Write-Host -ForegroundColor Green 'Create ExternalContributors.md'
# Create md file to store contributors information.
$contributorsMDFile = Join-Path $PSScriptRoot 'ExternalContributors.md'
if ((Test-Path -Path $contributorsMDFile)) {
    Remove-Item -Path $contributorsMDFile -Force
}
New-Item -ItemType "file" -Path $contributorsMDFile

#Check if the author exists in the specified organization。
#If yes return ture else retun false.
function IsAuthorExistOrg($authorOrgs, $orgLogin) {
    foreach($org in $authorOrgs)
    {
        if ($org.login -eq $orgLogin)
        {
            return $true
        }
    }
    return $false
}

$commitsUrl = "https://api.github.com/repos/Azure/azure-powershell/commits?since=$SinceDate&sha=$Branch"
$token = ConvertTo-SecureString $AccessToken -AsPlainText -Force
# Get last page number of commints.
$commintsPagesLink = (Invoke-WebRequest -Uri $commitsUrl -Authentication Bearer -Token $token).Headers.Link
$commintsLastPageNumber = 1 # Default value
if (![string]::IsNullOrEmpty($commintsPagesLink)) {
    if ($commintsPagesLink.LastIndexOf('&page=') -gt 0) {
        [int]$commintsLastPageNumber = $commintsPagesLink.Substring($commintsPagesLink.LastIndexOf('&page=') + '&page='.Length, 1) 
    }
}
$PRs = @()
for ($pageNumber=1; $pageNumber -le $commintsLastPageNumber; $pageNumber++) {
    $commitsPageUrl = $commitsUrl + "&page=$pageNumber"
    $PRs += Invoke-RestMethod -Uri $commitsPageUrl -Authentication Bearer -Token $token -ResponseHeadersVariable 'ResponseHeaders'
}

$sortPRs = $PRs | Sort-Object -Property @{Expression = {$_.author.login}; Descending = $False}

$skipContributors = @('aladdindoc')

$contributorsMDHeaderFlag = $True
for($PR = 0; $PR -lt $sortPRs.Length; $PR++) {
    if ($skipContributors.Contains($sortPRs[$PR].author.login))
    {
        continue
    }
    Invoke-RestMethod -Uri "https://api.github.com/orgs/Azure/members/$($sortPRs[$PR].author.login)" -Authentication Bearer -Token $token -ResponseHeadersVariable 'ResponseHeaders' -StatusCodeVariable 'StatusCode' -SkipHttpErrorCheck > $null
    if ($StatusCode -eq '204') {
        continue
    }
    if ($contributorsMDHeaderFlag) {
        Write-Host -ForegroundColor Green 'Output exteneral contributors infomation.'
        '### Thanks to our community contributors' | Out-File -FilePath $contributorsMDFile -Force
        Write-Host '### Thanks to our community contributors'
        $contributorsMDHeaderFlag = $False
    }
    $account = $sortPRs[$PR].author.login
    $name = $sortPRs[$PR].commit.author.name
    $index = $sortPRs[$PR].commit.message.IndexOf("`n`n")
    if($index -lt 0) {
        $commitMessage = $sortPRs[$PR].commit.message
    } else {
        $commitMessage = $sortPRs[$PR].commit.message.Substring(0, $index)
    }
    # The contributor hase many commits.
    if ( ($account -eq $sortPRs[$PR - 1].author.login) -or ($account -eq $sortPRs[$PR + 1].author.login)) {
        # Firt commit.
        if (!($sortPRs[$PR].author.login -eq $sortPRs[$PR - 1].author.login)) {
            if (($account -eq $name)) {
                "* @$account" | Out-File -FilePath $contributorsMDFile -Append -Force
                "  * $commitMessage" | Out-File -FilePath $contributorsMDFile -Append -Force

                Write-Host "* @$account"
                Write-Host "  * $commitMessage"
            } else {
                "* $($name) (@$account)" | Out-File -FilePath $contributorsMDFile -Append -Force
                "  * $commitMessage" | Out-File -FilePath $contributorsMDFile -Append -Force
                
                Write-Host "* $($name) (@$account)"
                Write-Host "  * $commitMessage"
            }
        } else
        {
            "  * $commitMessage" | Out-File -FilePath $contributorsMDFile -Append -Force

            Write-Host "  * $commitMessage"
        }
    } else {
        if (($account -eq $name)) {
            "* @$account, $commitMessage" | Out-File -FilePath $contributorsMDFile -Append -Force

            Write-Host "* @$account, $commitMessage"
        } else {
            "* $name (@$account), $commitMessage" | Out-File -FilePath $contributorsMDFile -Append -Force

            Write-Host "* $name (@$account), $commitMessage"
        }
    }
}



####################################################################################################################################################################################
# _______ _     _                     _                                          _ _   _               _              _____           _                     
# |__   __| |   (_)                   | |                                        (_) | | |             | |            / ____|         | |                    
#    | |  | |__  _ ___    ___ ___   __| | ___  __      ____ _ ___  __      ___ __ _| |_| |_ ___ _ __   | |__  _   _  | |  __ _ __ __ _| |__   __ _ _ __ ___  
#    | |  | '_ \| / __|  / __/ _ \ / _` |/ _ \ \ \ /\ / / _` / __| \ \ /\ / / '__| | __| __/ _ \ '_ \  | '_ \| | | | | | |_ | '__/ _` | '_ \ / _` | '_ ` _ \ 
#    | |  | | | | \__ \ | (_| (_) | (_| |  __/  \ V  V / (_| \__ \  \ V  V /| |  | | |_| ||  __/ | | | | |_) | |_| | | |__| | | | (_| | | | | (_| | | | | | |
#    |_|  |_| |_|_|___/  \___\___/ \__,_|\___|   \_/\_/ \__,_|___/   \_/\_/ |_|  |_|\__|\__\___|_| |_| |_.__/ \__, |  \_____|_|  \__,_|_| |_|\__,_|_| |_| |_|
#                                                                                                              __/ |                                         
#                                                                                                             |___/                                          
#####################################################################################################################################################################################
# Ensure you have the Microsoft.Graph module installed. run these in your console
# Install-Module Microsoft.Graph.users -Scope CurrentUser
# Install-Module ExchangeOnlineManagement -Scope CurrentUser

# Import the necessary modules
Import-Module ActiveDirectory
Import-Module ExchangeOnlineManagement
Import-Module Microsoft.Graph.users



# Admin sign-in to Exchange Online
Connect-ExchangeOnline
# Connect to Microsoft Graph
Connect-MgGraph -Scopes "User.ReadWrite.All", "Directory.ReadWrite.All"

# Parameters (replace with actual values or retrieve from input)
$displayName = Read-Host "Display name, ex; John Doe"
$mailNickname = Read-host "UserPrincipalName without @hrcrs or @3phalliance. We'll add these later ex; Jdoe"
$userPrincipalName = "$($mailNickname)@hrcrs.com"
$password = Read-Host "Enter temporary password" -AsSecureString
$jobTitle = Read-Host "Job Title"
$department = Read-Host "Department"
$UsageLocation = Read-Host "2 letter country code, ex; https://www.iso.org/iso-3166-country-codes.html"
# Create the user object
$newUserParams = @{
    AccountEnabled = $true
    DisplayName = $displayName
    UserPrincipalName = $userPrincipalName
    MailNickname = $mailNickname
    PasswordProfile = @{
        ForceChangePasswordNextSignIn = $true
        Password = $password
    }
    JobTitle = $jobTitle
    Department = $department
    UsageLocation = $UsageLocation
}

# Create the user
try {
    $newUser = New-MgUser @newUserParams
    Write-Host "User created successfully: $($newUser.Id)" -ForegroundColor Green
} catch {
    Write-Error "Failed to create user: $_"
}

# Get Business Premium SKU
$sku = Get-MgSubscribedSku | Where-Object { $_.SkuPartNumber -eq "SPB" -or $_.SkuPartNumber -eq "BUSINESS_PREMIUM" }

if (-not $sku) {
    Write-Error "Business Premium license not found in your tenant."
    exit
}

$licenseParams = @{
    AddLicenses = @(@{ SkuId = $sku.SkuId })
    RemoveLicenses = @()
}

try {
    Update-MgUserLicense -UserId $createdUser.Id -BodyParameter $licenseParams
    Write-Host " License assigned: $($sku.SkuPartNumber)"
} catch {
    Write-Error " Error assigning license: $_"
    exit
}

# ------------------- VERIFY MAILBOX -------------------

Start-Sleep -Seconds 60  # Wait for mailbox provisioning

$mailbox = Get-Mailbox -Identity $userPrincipalName -ErrorAction SilentlyContinue

if ($mailbox) {
    Write-Host "Mailbox successfully provisioned for $userPrincipalName"
} else {
    Write-Warning "Mailbox not found yet. It may still be provisioning."
}

# ------------------- DONE -------------------
# Disconnect from Exchange Online
Disconnect-ExchangeOnline -Confirm:$false

# Disconnect from Microsoft Graph
Disconnect-MgGraph
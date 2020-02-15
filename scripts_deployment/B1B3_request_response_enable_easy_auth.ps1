#Clear-AzContext -Scope CurrentUser -Force
#Connect-AzAccount

$id = "3405" # take same id in all B0/B1B3/B2 scripts

$rg = "test-funappsec" + $id + "-rg"
$funname = "test-funappsec" + $id + "-func"

# 0.2 connect to AAD
$Environment = "AzureCloud"
$aadConnection = Connect-AzureAD -AzureEnvironmentName $Environment

# 2. Creat App registration
# step 2 is derived from https://devblogs.microsoft.com/azuregov/web-app-easy-auth-configuration-using-powershell/
$Password = [System.Convert]::ToBase64String($([guid]::NewGuid()).ToByteArray())
$startDate = Get-Date
$PasswordCredential = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordCredential
$PasswordCredential.StartDate = $startDate
$PasswordCredential.EndDate = $startDate.AddYears(10)
$PasswordCredential.Value = $Password
$identifier_url = "https://" + $funname + ".azurewebsites.net"
[string[]]$reply_url = $identifier_url + "/.auth/login/aad/callback"
$reqAAD = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess"
$reqAAD.ResourceAppId = "00000002-0000-0000-c000-000000000000"
$delPermission1 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "311a71cc-e848-46a1-bdf8-97ff7156d8e6","Scope" #Sign you in and read your profile
$reqAAD.ResourceAccess = $delPermission1

$appRegName = $funname + "_easyauth"
$appReg = New-AzureADApplication -DisplayName $appRegName -IdentifierUris $identifier_url -Homepage $identifier_url -ReplyUrls $reply_url -PasswordCredential $PasswordCredential -RequiredResourceAccess $reqAAD

# 3. Add new AppRole object to app registration
# step 3 is derived from https://gist.github.com/psignoret/45e2a5769ea78ae9991d1adef88f6637
$newAppRole = [Microsoft.Open.AzureAD.Model.AppRole]::new()
$newAppRole.DisplayName = "Allow MSI SPN of ADFv2 to authenticate to Azure Function using its MSI"
$newAppRole.Description = "Allow MSI SPN of ADFv2 to authenticate to Azure Function using its MSI"
$newAppRole.Value = "Things.Read.All"
$Id = [Guid]::NewGuid().ToString()
$newAppRole.Id = $Id
$newAppRole.IsEnabled = $true
$newAppRole.AllowedMemberTypes = "Application"
$appRoles = $appReg.AppRoles
$appRoles += $newAppRole
$appReg | Set-AzureADApplication -AppRoles $appRoles

# 4. add app registration to web app
$authResourceName = $funname + "/authsettings"
$auth = Invoke-AzResourceAction -ResourceGroupName $rg -ResourceType Microsoft.Web/sites/config -ResourceName $authResourceName -Action list -ApiVersion 2016-08-01 -Force
$auth.properties.enabled = "True"
$auth.properties.unauthenticatedClientAction = "RedirectToLoginPage"
$auth.properties.tokenStoreEnabled = "True"
$auth.properties.defaultProvider = "AzureActiveDirectory"
$auth.properties.isAadAutoProvisioned = "False"
$auth.properties.clientId = $appReg.AppId
$auth.properties.clientSecret = $Password
$loginBaseUrl = $(Get-AzEnvironment -Name $environment).ActiveDirectoryAuthority
$auth.properties.issuer = $loginBaseUrl + $aadConnection.Tenant.Id.Guid + "/"
$auth.properties.allowedAudiences = @($identifier_url)
New-AzResource -PropertyObject $auth.properties -ResourceGroupName $rg -ResourceType Microsoft.Web/sites/config -ResourceName $authResourceName -ApiVersion 2016-08-01 -Force

# 5. Create SPN connected to app registration
$servicePrincipal = New-AzADServicePrincipal -ApplicationId $appReg.AppId -DisplayName $appRegName

# done 

# (optional, in case you want to whitelist AAD users)
# 6. Set "User assignment required?" to true in SPN
#Set-AzureADServicePrincipal -ObjectId $servicePrincipal.Id -AppRoleAssignmentRequired $true

# (optional, in case you want to whitelist AAD users)
# 7. Set obj of ADFv2 as only authorized user to log in web app (azure function) 
#$adfv2_resource = Get-AzDataFactoryV2 -ResourceGroupName $rg -Name $adfv2_name
#New-AzureADServiceAppRoleAssignment -ObjectId $adfv2_resource.Identity.PrincipalId -Id $newAppRole.Id -PrincipalId $adfv2_resource.Identity.PrincipalId -ResourceId $servicePrincipal.Id

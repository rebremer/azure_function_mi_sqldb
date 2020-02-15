#Clear-AzContext -Scope CurrentUser -Force
#Connect-AzAccount

$id = "3405" # take same id in all B0/B1B3/B2 scripts

$rg = "test-funappsec" + $id + "-rg"
$rg_sql = "test-funappsec" + $id + "-rg"
$loc = "westeurope"
$funname = "test-funappsec" + $id + "-func"
$vnet = "test-funappsec" + $id + "-vnet"
$subnet = "azurefunction"

$sqlserver = "test-funappsec" + $id + "-dbs"
$sqldb = "test-funappsec" + $id + "-sqldb"
$sqluser = "testfunappsec" + $id + "sqluser"
$pass = "<<SQLDB password, use https://passwordsgenerator.net/>>"
$aaduser = "<<your AAD email account>>"

# create logical SQL server and SQLDB
az sql server create -l $loc -g $rg_sql -n $sqlserv -u sqluser -p $pass
az sql db create -g $rg_sql -s $sqlserver -n $sqldb --service-objective Basic --sample-name AdventureWorksLT

# Configure AAD access to logical SQL server
# Connect-AzureAD
Set-AzSqlServerActiveDirectoryAdministrator -ResourceGroupName $rg_sql -ServerName $sqlserver -DisplayName $aaduser 

# log in SQL with AAD (e.g. via portal query editor, SSMS or VSC)
# Execute following SQL statement
#CREATE USER [<<your azure function name, equal to $funname>>] FROM EXTERNAL PROVIDER;
#EXEC sp_addrolemember [db_datareader], [<<your azure function name, equal to $funname>>];

# point app settings to database
az functionapp config appsettings set --name $funname --resource-group $rg --settings sqlserver=$sqlserver sqldb=$sqldb

# Add firewall rules
$subnetobject = Get-AzVirtualNetwork -ResourceGroupName $rg -Name $vnet | Get-AzVirtualNetworkSubnetConfig -Name $subnet
New-AzSqlServerVirtualNetworkRule -ResourceGroupName $rg_sql -ServerName $sqlserver -VirtualNetworkRuleName $subnet -VirtualNetworkSubnetId $subnetobject.Id

# upload code Azure Function
# To create Azure Function in Python, see https://github.com/MicrosoftDocs/azure-docs/blob/master/articles/azure-functions/functions-create-first-function-python.md
# Get code from __init__.py and requirements.txt from this git repo, then run command below

func azure functionapp publish $funname
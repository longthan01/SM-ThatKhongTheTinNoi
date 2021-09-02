
. .\IISModules.ps1

$DEFAULT_CERT_CN = ".ansarada.com"
$SubscriptionProvisioning = [PSCustomObject]@{
    HostRecord  = @{Ip = "127.0.0.1"; Address = "subscription-provisioning.local.core.ansarada.com" };
    AppPoolName = "web_subscription-provisioning.local.core.ansarada.com";
    ProjectPath = "C:\Git\subscription-provisioning-mock\ServiceHost";
    SitePath    = "C:\inetpub\wwwroot\subscription-provisioning-mock";
    IISSiteName = "web_subscription-provisioning.local.core.ansarada.com";
    PortBinding = 443;
}


$DreamLiner = [PSCustomObject]@{
    HostRecord  = @{Ip = "127.0.0.1"; Address = "dreamliner-api-server.local.core.ansarada.com" };
    AppPoolName = "app_dreamliner-api-server.local.core.ansarada.com";
    ProjectPath = "C:\Git\dreamliner-mock\ServiceHost";
    SitePath    = "C:\inetpub\wwwroot\dreamliner-mock";
    IISSiteName = "web_dreamliner-api-server.local.core.ansarada.com";
    PortBinding = 443;
}

$ProfileApiMock = [PSCustomObject]@{
    HostRecord  = @{Ip = "127.0.0.1"; Address = "identity-profiles-api.local.core.ansarada.com" };
    AppPoolName = "identity-profiles-api.local.core.ansarada.com";
    ProjectPath = "C:\Git\profiles-api-mock\ServiceHost";
    SitePath    = "C:\inetpub\wwwroot\profiles-api-mock";
    IISSiteName = "web_identity-profiles-api.local.core.ansarada.com";
    PortBinding = 443;
}

$Auth0Mock = [PSCustomObject]@{
    HostRecord  = @{Ip = "127.0.0.1"; Address = "auth-au.ansarada.dev" };
    ProjectPath = "C:\Git\auth0-mock\src\ServiceHost";
    SitePath    = "C:\inetpub\wwwroot\auth0-mock";
    AppPoolName = "app_auth-au.ansarada.dev";
    IISSiteName = "web_auth-au.ansarada.dev";
    PortBinding = 4343;
    CertCN      = ".ansarada.dev";
}

$ServiceApi2 = [PSCustomObject]@{
    HostRecord            = @{Ip = "127.0.0.1"; Address = "servicesapi2-services.local.dataroom.ansarada.com" };
    ProjectPath           = "C:\git\microservices.dataroom.servicesapi2\Src\Ansarada.DataRoom.ServicesApi2";
    SitePath              = "C:\inetpub\wwwroot\servicesapi2";
    AppPoolName           = "servicesapi2.ansarada.prod";
    IISSiteName           = "servicesapi2.ansarada.prod";
    RebindAppPoolIdentity = $false;
    PortBinding           = 443;
    CertCN                = ".ansarada.com";
}

function Main {
    if (Get-IISState) {
        wh "Starting IIS..."
        iisreset /start
    }

    New-IISService $SubscriptionProvisioning 
    New-IISService $DreamLiner 
    New-IISService $ProfileApiMock
    Add-DbLoginForProfileApi

    New-IISService $Auth0Mock
    New-IISService $ServiceApi2

}

function Add-DbLoginForProfileApi {
    $query = @"
    USE dbDataRoom
    GO
    IF SUSER_ID('ProfilesApiMock') IS NULL
        CREATE LOGIN ProfilesApiMock WITH PASSWORD = 'p@ssw0rd'
    GO
    IF USER_ID('ProfilesApiMock') IS NULL
        CREATE USER ProfilesApiMock FOR LOGIN ProfilesApiMock
    GO
    GRANT SELECT TO ProfilesApiMock
    GO
"@
    try {
        Invoke-Sqlcmd -ServerInstance '.' -Query $query
    }
    catch {
        $errorMessage = $_.Exception.Message
        if ($errorMessage.Contains("already exist")) {
            wh "Login already exist" $color_warning
        }
    }
}

Main
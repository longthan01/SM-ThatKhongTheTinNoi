
Import-Module WebAdministration
. .\Utilities.ps1

# Configuration example
# $ServiceApi2 = [PSCustomObject]@{
#     HostRecord            = @{Ip = "127.0.0.1"; Address = "servicesapi2-services.local.dataroom.ansarada.com" };
#     ProjectPath           = "C:\git\microservices.dataroom.servicesapi2\Src\Ansarada.DataRoom.ServicesApi2";
#     SitePath              = "C:\inetpub\wwwroot\servicesapi2";
#     AppPoolName           = "servicesapi2.ansarada.prod";
#     IISSiteName           = "servicesapi2.ansarada.prod";
#     RebindAppPoolIdentity = $false;
#     PortBinding           = 443;
#     CertCN                = ".ansarada.com";
# }

function Set-AppPoolIdentity($config) {
    $credentials = (Get-Credential -Message "Please enter the Login credentials including Domain Name").GetNetworkCredential()
    $userName = $credentials.UserName
    if (![string]::IsNullOrEmpty($credentials.Domain)) {
        $userName = $credentials.Domain + '\' + $credentials.UserName
    }
    Set-ItemProperty IIS:\AppPools\$($config.AppPoolName) -name processModel.identityType -Value SpecificUser 
    Set-ItemProperty IIS:\AppPools\$($config.AppPoolName) -name processModel.userName -Value $username
    Set-ItemProperty IIS:\AppPools\$($config.AppPoolName) -name processModel.password -Value $credentials.Password
}

function Add-HostFileEntry($ip, $address) {
    $HostFile = 'C:\Windows\System32\drivers\etc\hosts'
 
    # Create a backup copy of the Hosts file
    $dateFormat = (Get-Date).ToString('dd-MM-yyyy hh-mm-ss')
    $FileCopy = $HostFile + '.' + $dateFormat + '.copy'
    Copy-Item $HostFile -Destination $FileCopy
 
    #Hosts to Add
    # Get the contents of the Hosts file
    $File = Get-Content $HostFile
 
    # write the Entries to hosts file, if it doesn't exist.
    wh "Checking existing HOST file entries for $address..."
     
    #Set a Flag
    $EntryExists = $false
     
    if ($File -contains "$ip `t $address") {
        wh "Host File Entry for $address is already exists, skip adding"
        $EntryExists = $true
    }
    #Add Entry to Host File
    if (!$EntryExists) {
        wh "Adding Host File Entry for $address"
        Add-content -path $HostFile -value "`r`n$ip `t $address"
    }
}

function Get-IISState {
    $iis = Get-WmiObject Win32_Service -Filter "Name = 'IISADMIN'" -ComputerName "."
    return $iis.State
}

function Get-Certificate($dnsNameSuffix) {
    $bindings = Get-ChildItem -Path IIS:SSLBindings
    foreach ($b in $bindings) {
        if ($b.Sites) {
            $certificate = Get-ChildItem -Path CERT:LocalMachine/My |
            Where-Object -Property Thumbprint -EQ -Value $b.Thumbprint

            foreach ($cert in $certificate) {
                foreach ($name in $cert.DnsNameList) {
                    if ($name.ToString().Contains($dnsNameSuffix)) {
                        return $b.Thumbprint
                    }
                }
               
            }
        }
    }
    wh "Certificate not found" $color_warning
    return $null
}

function New-IISAppPool($config) {
    if (Test-Path "IIS:\AppPools\$($config.AppPoolName)") {
        wh "Application pool $($config.AppPoolName) already exist, skip creating"
    }
    else {
        $newAppPool = New-WebAppPool -Name $config.AppPoolName
        $newAppPool.autoStart = "true"
        $newAppPool | Set-Item
        # Set app pool CLR to no managed code
        Set-ItemProperty -Path "IIS:\AppPools\$($config.AppPoolName)" managedRuntimeVersion ""
        wh "Setting up app pool identity..."
    }
    if ($config.RebindAppPoolIdentity) {
        Set-AppPoolIdentity $config
    }
}

function New-IISApplication($config) {
    $website = Get-IISSite $config.IISSiteName
    $websiteExisting = $false;
    if ($null -ne $website) {
        wh "Website $($config.IISSiteName) already exist, skip creating"
        $websiteExisting = $true
    }
    $certCN = $config.CertCN
    if ([string]::IsNullOrEmpty($certCN)) {
        $certCN = $DEFAULT_CERT_CN
    }
    $cert = Get-Certificate $certCN
    wh "Found self-signed cert corresponding to $($config.CertCN) with thumbprint $cert"
    if ($websiteExisting -eq $false) {
        $website = New-IISSite -Name $config.IISSiteName -BindingInformation "*:$($config.PortBinding):$($config.HostRecord.Address)" -PhysicalPath $config.SitePath -Protocol https -CertificateThumbPrint "$($cert)" -CertStoreLocation "Cert:\LocalMachine\My"
    }
    wh "Setting up $($config.IISSiteName) to application pool $($config.AppPoolName)"
    $website.Applications["/"].ApplicationPoolName = $config.AppPoolName
}

function Publish-WebApp($config, $action = 'publish') {
    $WaitSec = 10
    $SleepMillisec = 100
    $StartUtc = (Get-Date).ToUniversalTime()
    $appPoolState = Get-WebAppPoolState -Name  $config.AppPoolName
    if ($appPoolState.Value -ne "Stopped") {
        Stop-WebAppPool $config.AppPoolName
    }
    if (!(Test-Path -Path $config.SitePath)) {
        mkdir $config.SitePath
    }
    while ($true) {
        Start-Sleep -Milliseconds $SleepMillisec

        #if wait time expired
        if (((Get-Date).ToUniversalTime() - $StartUtc).TotalSeconds -gt $WaitSec) {
            wh "App pool $($config.AppPoolName) did not stop after $WaitSec sec, exiting..." $color_error
            break
        }
        #if app pool has stopped
        if ((Get-WebAppPoolState $config.AppPoolName).Value -eq "Stopped") {
            if ($action -eq 'build') {
                dotnet build $config.ProjectPath -v minimal
            }
            else {
                if ($action -eq 'publish') {
                    dotnet publish $config.ProjectPath -o $config.SitePath -v minimal
                }
            }
            break
        }
    }
    wh "Starting web application pool $($config.AppPoolName)"
    Start-WebAppPool $config.AppPoolName
    wh "Starting IIS site $($config.IISSiteName)..."
    Start-IISSite -Name $config.IISSiteName
}

function New-IISService($config) {
    New-IISAppPool $config
    New-IISApplication $config
    Publish-WebApp $config
    Add-HostFileEntry $config.HostRecord.Ip $config.HostRecord.Address
}

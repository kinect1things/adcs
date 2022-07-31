# VARIABLES #
$IssuingCAName = ""
$RootCAName = ""
$DomainDN = ""
$HTTPUrl = "pki.domain.com"
$RootCAIP = "servername"
$RootCreds = Get-Credential -Message "Enter Administrator Credentials for the Root CA"
Add-WindowsFeature ADCS-Cert-Authority -IncludeManagementTools -Verbose
Add-WindowsFeature ADCS-Web-Enrollment, Web-Mgmt-Console, Web-Mgmt-Compat, Web-Metabase -Verbose
Add-WindowsFeature ADCS-Cert-Authority -IncludeManagementTools -Verbose
Install-ADCSCertificationAuthority -CACommonName $IssuingCAName -CAType EnterpriseSubordinateCA -CryptoProviderName "RSA#Microsoft Software Key Storage Provider" -HashAlgorithmName SHA256 -KeyLength 2048 -Verbose -OverwriteExistingKey -OverwriteExistingCAinDS -Force 
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\CertSvc\Configuration\$IssuingCAName" -Name CRLDeltaPeriodUnits -Value 0
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\CertSvc\Configuration\$IssuingCAName" -Name CRLDeltaPeriod -Value "Days"
#AIA
certutil -setreg CA\CACertPublicationURLs "1:C:\Windows\system32\CertSrv\CertEnroll\%1_%3%4.crt\n3:ldap:///CN=%7,CN=AIA,CN=Public Key Services,CN=Services,%6%11\n0:http://%1/CertEnroll/%1_%3%4.crt\n0:file://%1/CertEnroll/%1_%3%4.crt\n2:http://$HTTPUrl/%3%4.crt"
#CDP
certutil -setreg CA\CRLPublicationURLs "65:C:\Windows\system32\CertSrv\CertEnroll\%3%8%9.crl\n79:ldap:///CN=%7%8,CN=%2,CN=CDP,CN=Public Key Services,CN=Services,%6%10\n0:http://%1/CertEnroll/%3%8%9.crl\n0:file://%1/CertEnroll/%3%8%9.crl\n6:http://$HTTPUrl/%3%8.crl"
#Audit
Certutil -setreg CA\AuditFilter 127
#Get Root CA and CRL
Remove-Item -Path C:\inetpub\wwwroot\*
New-PSDrive -Name "RootCA" -PSProvider FileSystem -Root "\\$RootCAIP\C$" -Credential $RootCreds
Copy-Item RootCA:\Windows\System32\CertSrv\CertEnroll\* C:\inetpub\wwwroot\ -Force -Verbose
$RootCert = (Get-Item -Path C:\inetpub\wwwroot\*.crt).Name
Rename-Item -Path "C:\inetpub\wwwroot\$RootCert" -NewName "$RootCAName.crt"
$RootCert = (Get-Item -Path C:\inetpub\wwwroot\*.crt).Name
certutil -addstore "Root" "C:\inetpub\wwwroot\$RootCert"
#Configure IIS
C:\Windows\System32\inetsrv\appcmd.exe set config /section:requestfiltering /allowdoubleescaping:true
C:\Windows\System32\inetsrv\appcmd.exe set config /section:system.webServer/directoryBrowse /enabled:"True" /showFlags:"Date, Time, Size, Extension"
iisreset
#Issue Certificate to Issuing CA
New-Item -ItemType Directory -Path RootCA:\Temp -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path C:\Temp -Force -ErrorAction SilentlyContinue
$RequestFile = (Get-Item -Path C:\\*.req).Name
certreq -submit -f -config "$RootCAIP\$RootCAName" "C:\$RequestFile" C:\Temp\IssuingCA.cer
Write-Host "
******************************************************************
1. On the Root CA issue the Certificate Under 'Pending Requests'
2. Export the Certificate to C:\Temp\IssuingCA.cer
3. Create the DNS record for $HTTPUrl
Press Enter when completed...
******************************************************************
" -ForegroundColor Red
Pause
#Copy Issuing Cert and Install Issuing CA Certificate
Copy-Item -Path RootCA:\Temp\IssuingCA.cer C:\Temp\ -Force -Verbose
certutil -installcert C:\Temp\IssuingCA.cer
#Copy CRL and Cert to CDP
Start-Service -Name CertSvc
certutil -crl
Sleep 3
Copy-Item C:\Windows\System32\certsrv\CertEnroll\* C:\inetpub\wwwroot\ -Verbose -Force
$IssuingCert = (Get-Item -Path C:\inetpub\wwwroot\*Issuing*.crt).Name 
Rename-Item -Path "C:\inetpub\wwwroot\$IssuingCert" -NewName "$IssuingCAName.crt"
#Cleanup
Remove-Item -Path RootCA:\Temp\* -Recurse -ErrorAction SilentlyContinue
Remove-Item -Path C:\Temp -Recurse -ErrorAction SilentlyContinue
Remove-Item -Path C:\*.req -ErrorAction SilentlyContinue
Restart-Computer
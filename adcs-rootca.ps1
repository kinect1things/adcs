# VARIABLES #
$RootCAName = ""
$DomainDN = ""
$HTTPUrl = ""
Add-WindowsFeature ADCS-Cert-Authority -IncludeManagementTools -Verbose
Install-ADCSCertificationAuthority -CACommonName $RootCAName -CAType StandaloneRootCA -CryptoProviderName "RSA#Microsoft Software Key Storage Provider" -HashAlgorithmName SHA512 -KeyLength 4096 -ValidityPeriod Years -ValidityPeriodUnits 20 -OverwriteExistingKey -Verbose -Force
#Basic Configuration
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\CertSvc\Configuration\$RootCAName" -Name DSConfigDN -Value "CN=Configuration,$DomainDN"
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\CertSvc\Configuration\$RootCAName" -Name DSDomainDN -Value "$DomainDN"
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\CertSvc\Configuration\$RootCAName" -Name ValidityPeriodUnits -Value 20
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\CertSvc\Configuration\$RootCAName" -Name ValidityPeriod -Value "Years"
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\CertSvc\Configuration\$RootCAName" -Name CRLPeriodUnits -Value 20
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\CertSvc\Configuration\$RootCAName" -Name CRLPeriod -Value "Years"
#AIA
certutil -setreg CA\CACertPublicationURLs "1:C:\Windows\system32\CertSrv\CertEnroll\%1_%3%4.crt\n0:ldap:///CN=%7,CN=AIA,CN=Public Key Services,CN=Services,%6%11\n0:http://%1/CertEnroll/%1_%3%4.crt\n0:file://%1/CertEnroll/%1_%3%4.crt\n2:http://$HTTPUrl/%3%4.crt"
#CDP
certutil -setreg CA\CRLPublicationURLs "65:C:\Windows\system32\CertSrv\CertEnroll\%3%8%9.crl\n0:ldap:///CN=%7%8,CN=%2,CN=CDP,CN=Public Key Services,CN=Services,%6%10\n0:http://%1/CertEnroll/%3%8%9.crl\n0:file://%1/CertEnroll/%3%8%9.crl\n6:http://$HTTPUrl/%3%4.crl"
#Audit
Certutil -setreg CA\AuditFilter 127
#Publish and Rename
Restart-Service -Name CertSvc -Force -Verbose
certutil -crl
sleep 3
# Cleanup
Restart-Computer
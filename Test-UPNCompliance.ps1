Function Test-UPNCompliance{
    <#
    .SYNOPSIS
        Script to test UPN compliance accross mail and primaryproxyaddress in preparation of Azure AD Connect sync..
    .DESCRIPTION
        Script to test UPN compliance accross mail and primaryproxyaddress in preparation of Azure AD Connect sync.
        See more information https://docs.microsoft.com/en-us/microsoft-365/enterprise/prepare-for-directory-synchronization?view=o365-worldwide#2-directory-object-and-attribute-preparation
    .EXAMPLE
        PS C:\> Test-UPNCompliance -ManuallyUsers upn2
        DistinguishedName    : CN=upn2,OU=Users,OU=ASP,DC=david,DC=local
        mail                 : upn2@daviddemo.se
        Userprincipalname    : upn2@daviddemo.se
        primaryProxyaddress  : upn2@daviddemo.se
        LocalDomainSuffixUPN : False
        Compliant            : True
        ErrorMsg             : 

        PS C:\> Test-UPNCompliance -ObjectUser (Get-aduser upn2 -Properties mail, proxyaddresses)
        DistinguishedName    : CN=upn2,OU=Users,OU=ASP,DC=david,DC=local
        mail                 : upn2@daviddemo.se
        Userprincipalname    : upn2@daviddemo.se
        primaryProxyaddress  : upn2@daviddemo.se
        LocalDomainSuffixUPN : False
        Compliant            : True
        ErrorMsg             : 

        PS C:\> Test-UPNCompliance -AllUsers
        DistinguishedName    : CN=upn2,OU=Users,OU=ASP,DC=david,DC=local
        mail                 : upn2@daviddemo.se
        Userprincipalname    : upn2@daviddemo.se
        primaryProxyaddress  : upn2@daviddemo.se
        LocalDomainSuffixUPN : False
        Compliant            : True
        ErrorMsg             : 
    .INPUTS
        Inputs (if any)
    .OUTPUTS
        Output (if any)
    .NOTES
        General notes
    #>
    [CmdletBinding()]
    param(
        [Parameter(ParameterSetName = 'ObjectUser')]
        $ObjectUser, #Måste vara get-aduser med -properties mail, proxyaddresses
        [Parameter(ParameterSetName = 'AllUsers')]
        [switch]$AllUsers,
        [Parameter(ParameterSetName = 'ManuallyUsers')]
        $ManuallyUsers
    )#End param

    begin{
        $returnArray = [System.Collections.ArrayList]@()
        if($PSCmdlet.ParameterSetName -like "Allusers"){
            $Users = Get-Aduser -Filter * -properties mail, proxyaddresses
        }#End if
        elseif($PSCmdlet.ParameterSetName -like "ObjectUser"){
            $Users = $ObjectUser
        }#End elseif
        else{
            $Users = Get-Aduser $ManuallyUsers -properties mail, proxyaddresses
        }#End else

        $WrongSuffixDomains = "local"
    }#End begin

    process{
        foreach($User in $Users){
            $primaryProxyaddress = $null
            $LocalDomainSuffix = $false
            $Compliant = $True
            $ErrorMsg = ""

            if($User.proxyaddresses){
                $primaryProxyaddress = ($User.proxyaddresses | Where-Object{$_ -clike "SMTP:*"}) -replace "SMTP:", ""
                $primaryProxyaddress = $primaryProxyaddress.ToLower()
                
                ### Testa mail.
                if(!($User.mail)){
                    $Compliant = $false
                    $ErrorMsg += "Missing mail.;"
                }#End if
                else{
                    if(!($primaryProxyaddress -eq $user.mail)){
                        $Compliant = $false
                        $ErrorMsg += "Mail and proxy doesnt match.;"
                    }#End if
                }#End else
                ###

                ### Testa UPN
                if(!($User.Userprincipalname)){
                    $Compliant = $false
                    $ErrorMsg += "Missing UPN.;"
                }#End if
                else{
                    if($User.Userprincipalname.EndsWith($WrongSuffixDomains)){
                        $LocalDomainSuffix = $True
                        $Compliant = $false
                        $ErrorMsg += "Local domain on UPN.;"
                    }#End if

                    if(!($primaryProxyaddress -eq $user.Userprincipalname)){
                        $Compliant = $false
                        $ErrorMsg += "UPN and proxy doesnt match.;"
                    }#End if
                }#End else

            }#End if
            else {
                $Compliant = $false
                $ErrorMsg += "Missing epost, wont test anything.;"
            }#End else

            if($ErrorMsg.length -eq 0){
                $ErrorMsg = $null
            }#End if
            else{
                $ErrorMsg = $ErrorMsg.substring(0, $ErrorMsg.length - 1)
            }#End else

            $customObject = New-Object System.Object
            $customObject | Add-Member -Type NoteProperty -Name DistinguishedName -Value $User.DistinguishedName
            $customObject | Add-Member -Type NoteProperty -Name mail -Value $User.mail
            $customObject | Add-Member -Type NoteProperty -Name Userprincipalname -Value $User.Userprincipalname
            $customObject | Add-Member -Type NoteProperty -Name primaryProxyaddress -Value $primaryProxyaddress
            $customObject | Add-Member -Type NoteProperty -Name LocalDomainSuffixUPN -Value $LocalDomainSuffix
            $customObject | Add-Member -Type NoteProperty -Name Compliant -Value $Compliant
            $customObject | Add-Member -Type NoteProperty -Name ErrorMsg -Value $ErrorMsg
            $returnArray.add($customObject) | Out-Null
        }#End foreach
    }#End process

    end{
        return $returnArray
    }#End end
}#End function

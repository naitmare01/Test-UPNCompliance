Function Test-UPNCompliance{
    <#
    .SYNOPSIS
        Script to test UPN compliance accross mail and primaryproxyaddress in preparation of Azure AD Connect sync.
    .DESCRIPTION
        Script to test UPN compliance accross mail and primaryproxyaddress in preparation of Azure AD Connect sync.
        This script will check for primarysmtpaddress and validate if UPN and mail is the same value.

        For users without primarysmtpaddress thiw script will validate UPN against samaccountname and mail.
        
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
        $ObjectUser, #Ha to object from Get-AdUser with -properties mail, proxyaddresses
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
            $HasMailBox = $false
            $UPNAndProxyMatch = $null
            $ErrorMsg = ""

            if($User.proxyaddresses){
                $HasMailBox = $true
                $primaryProxyaddress = ($User.proxyaddresses | Where-Object{$_ -clike "SMTP:*"}) -replace "SMTP:", ""
                $primaryProxyaddress = $primaryProxyaddress.ToLower()
                
                ### test mail.
                if(!($User.mail)){
                    $Compliant = $false
                    $ErrorMsg += "Missing mail.;"
                }#End if
                else{
                    if(!($primaryProxyaddress -eq $user.mail)){
                        $Compliant = $false
                        $ErrorMsg += "Mail and proxyaddresses doesnt match.;"
                    }#End if
                }#End else
                ###

                ### test UPN
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
                        $UPNAndProxyMatch = $False
                        $ErrorMsg += "UPN and proxyaddresses doesnt match.;"
                    }#End if
                    else{
                        $UPNAndProxyMatch = $True
                    }#End else
                }#End else

            }#End if
            else{
                if(!($User.Userprincipalname)){
                    $Compliant = $false
                    $ErrorMsg += "Missing UPN and proxyaddresses. Wont test anything;"
                }#End if
                else{
                    
                    ### test mail
                    if(!($User.mail)){
                        $Compliant = $false
                        $ErrorMsg += "Missing mail.;"
                    }#End if
                    else{
                        if(!($User.Userprincipalname -eq $user.mail)){
                            $Compliant = $false
                            $ErrorMsg += "Mail and UPN doesnt match.;"
                        }#End if
                    }#End else
                    ###

                    ### test samaccountname
                    if(!($User.samaccountname)){
                        $Compliant = $false
                        $ErrorMsg += "Missing samaccountname.;"
                    }#End if
                    else{
                        $tempupn = ($user.userprincipalname -split '@')[0]
                        if(!($tempupn -eq $User.samaccountname)){
                            $Compliant = $false
                            $ErrorMsg += "UPN-prefix and samaccountname doesnt match.;"
                        }#End if
                    }#End else
                    ###
                }#End else
            }#End else

            if($ErrorMsg.length -eq 0){
                $ErrorMsg = $null
            }#End if
            else{
                $ErrorMsg = $ErrorMsg.TrimEnd(';')
            }#End else

            $customObject = New-Object System.Object
            $customObject | Add-Member -Type NoteProperty -Name DistinguishedName -Value $User.DistinguishedName
            $customObject | Add-Member -Type NoteProperty -Name samaccountname -Value $User.samaccountname
            $customObject | Add-Member -Type NoteProperty -Name mail -Value $User.mail
            $customObject | Add-Member -Type NoteProperty -Name Userprincipalname -Value $User.Userprincipalname
            $customObject | Add-Member -Type NoteProperty -Name primaryProxyaddress -Value $primaryProxyaddress
            $customObject | Add-Member -Type NoteProperty -Name LocalDomainSuffixUPN -Value $LocalDomainSuffix
            $customObject | Add-Member -Type NoteProperty -Name UPNAndProxyMatch -Value $UPNAndProxyMatch
            $customObject | Add-Member -Type NoteProperty -Name HasMailBox -Value $HasMailBox
            $customObject | Add-Member -Type NoteProperty -Name Compliant -Value $Compliant
            $customObject | Add-Member -Type NoteProperty -Name ErrorMsg -Value $ErrorMsg
            $returnArray.add($customObject) | Out-Null
        }#End foreach
    }#End process

    end{
        return $returnArray
    }#End end
}#End function

Function Set-CorrectUPN{
        <#
    .SYNOPSIS
        This funciton takes an input object from the Function Test-UPNCompliance and tries to correct upn, mail and primaryproxyaddress.
    .DESCRIPTION
        This funciton takes an input object from the Function Test-UPNCompliance and tries to correct upn, mail and primaryproxyaddress.
        
        See more information https://docs.microsoft.com/en-us/microsoft-365/enterprise/prepare-for-directory-synchronization?view=o365-worldwide#2-directory-object-and-attribute-preparation
    .EXAMPLE
    .INPUTS
        Inputs (if any)
    .OUTPUTS
        Output (if any)
    .NOTES
        General notes
    #>
    [CmdletBinding()]
    param(
        #Must be object from Test-UPNCompliance
        [Parameter(Mandatory = $True)]
        [object]$Users
    )#End param

    begin{
        #$returnArray = [System.Collections.ArrayList]@()
        $UsedUPN = [System.Collections.ArrayList]@()
        $Users = $Users | Where-Object{$_.compliant -eq $false}
    }#End begin

    process{
        foreach($user in $users){
            $SamaccountName = $User.SamaccountName
            #Handle error when UPN and Proxyaddress doesnt match.
            if($user.UPNAndProxyMatch -eq $false){
                $NewUPN = $User.primaryProxyaddress
                if($NewUPN -in $UsedUPN){
                    Write-Warning "$NewUPN already used during this run. Wont change anything on user with samaccountname $samaccountname"
                    continue
                }#End if
                else{
                    if(Get-ADUser -filter{Userprincipalname -like $newupn}){
                        Write-Warning "$NewUPN already taken in AD. Wont change anything on user with samaccountname $samaccountname"
                        continue
                    }#End if
                    else{
                        Write-Verbose "Will change UPN to $NewUpn on on user with samaccountname $samaccountname"
                        $UsedUPN.add($newupn) | Out-Null
                        Set-ADUser $samaccountname -userprincipalname $newupn -confirm:$false
                    }#End else
                }#End else
            }#End if
            Test-UPNCompliance -ManuallyUsers $samaccountname
        }#End foreach
    }#End process

    end{
        #return $returnArray
    }#End end

}#End function

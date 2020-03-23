[CmdletBinding()]
[OutputType([System.Data.DataSet])]
param (
    [Parameter(Mandatory, ValueFromPipeline)]
    [System.Data.DataSet]$DataSet


)

#region Define Schema properties that this script applies to

$supportedBaseTypeNames = 'NetAppDocs.NcController', 'NetAppDocs.NcControllerAsup'
$minimumSchemaVersion = [version]::Parse('3.4.0')

if ($DataSet.ExtendedProperties['BaseTypeName'] -notin $supportedBaseTypeNames) {
    Write-Warning -Message 'The custom script specified does not support the system type contained in this DataSet.'

    return $DataSet
}

#if ([version]$DataSet.ExtendedProperties['SchemaVersion'] -lt $minimumSchemaVersion) {
#    Write-Warning -Message "The custom script specified requires a DataSet generated with NetAppDocs v$minimumSchemaVersion or later."

#    return $DataSet
#}

# Classification: Use LOW, MID, HIGH
$classification = "HIGH"
#endregion
$sanitize = 0
$folder = "$($PSScriptRoot)\$(Get-Date -Format MM_dd_yyyy)"
if (Test-Path -path "$($folder)\reference.xml")
{
    Write-Host "Sanitizing File"
    $sanitize = 1
    [xml]$XmlDocument = Get-Content "$($folder)\reference.xml"
    $sanitization_reference =  $($XmlDocument.Sanitization.Sections.ChildNodes | ? {$_.name -like 'ClusterName'}).mappings.mapping
}



#Pull the cluster information from the Text File, including the Location and Environment.  The Network is determined from the $classification variable in the user section above.
$clusters = @()
foreach ($cluster_info in Get-Content "$($PSScriptRoot)\All_Systems.txt" | ? {$_ -ne ""}){
    $item = $cluster_info.split(',')
    $item += $classification
    $reference = New-Object psobject
    $reference | Add-Member -MemberType NoteProperty -Name Cluster -Value $item[0]
    $reference | Add-Member -MemberType NoteProperty -Name 'IP Address' -value $item[1]
    $reference | Add-Member -MemberType NoteProperty -Name Location -Value $item[2]
    $reference | Add-Member -MemberType NoteProperty -Name Environment -value $item[3]
    $reference | Add-Member -MemberType NoteProperty -Name Network -value $item[4]
    if ($sanitize -eq 1){
        $reference | Add-Member -MemberType NoteProperty -Name SanitizedString -value $($sanitization_reference | ? {$_.securestring -eq $($item[0])}).sanitizedstring
    }
    $clusters += $reference
}
Write-Verbose -Message 'Adding new columns to all tables'

    # For each Table in the Dataset, create a new 'Environment', 'Network', and 'Location' column after the Cluster UUID column.  The Cluster UUID column is hidden on some of the worksheets within the NetAppDocs output.
    # After the three new columns are created, populate each row with the proper Environment, Network, Location information for that cluster.
foreach ($Table in $Dataset.Tables.tablename){
    ($DataSet.Tables[$Table].Columns.Add('Environment', [System.String])).SetOrdinal($DataSet.Tables[$Table].Columns['Cluster UUID'].Ordinal + 1)
    $DataSet.Tables[$Table].Columns['Environment'].Caption = 'Environment'

    ($DataSet.Tables[$Table].Columns.Add('Network', [System.String])).SetOrdinal($DataSet.Tables[$Table].Columns['Cluster UUID'].Ordinal + 1)
    $DataSet.Tables[$Table].Columns['Network'].Caption = 'Network'

    ($DataSet.Tables[$Table].Columns.Add('Location', [System.String])).SetOrdinal($DataSet.Tables[$Table].Columns['Cluster UUID'].Ordinal + 1)
    $DataSet.Tables[$Table].Columns['Location'].Caption = 'Location'

    #Populate the new columns in NodeDetails
    foreach ($row in $DataSet.Tables[$Table]){
        # Populate the new column, Non-Sanitized
        if ($sanitize -eq 0){ 
                $row.Environment = $($clusters | ? {$_.Cluster -like $($row.ClusterName)}).Environment
                $row.Network = $($clusters | ? {$_.Cluster -like $($row.ClusterName)}).Network
                $row.Location = $($clusters | ? {$_.Cluster -like $($row.ClusterName)}).Location
        }else {
                # Populate the new column, Sanitized
                $row.Environment = $($clusters | ? {$_.SanitizedString -like $($row.ClusterName)}).Environment
                $row.Network = $($clusters | ? {$_.SanitizedString -like $($row.ClusterName)}).Network
                $row.Location = $($clusters | ? {$_.SanitizedString -like $($row.ClusterName)}).Location
        }
    }
}




# Return the DataSet to the pipeline
$DataSet

# SIG # Begin signature block
# MIIYjQYJKoZIhvcNAQcCoIIYfjCCGHoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUn/uCZkLFO4ucK5ju86dWMCmx
# L1igghLlMIIEFDCCAvygAwIBAgILBAAAAAABL07hUtcwDQYJKoZIhvcNAQEFBQAw
# VzELMAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExEDAOBgNV
# BAsTB1Jvb3QgQ0ExGzAZBgNVBAMTEkdsb2JhbFNpZ24gUm9vdCBDQTAeFw0xMTA0
# MTMxMDAwMDBaFw0yODAxMjgxMjAwMDBaMFIxCzAJBgNVBAYTAkJFMRkwFwYDVQQK
# ExBHbG9iYWxTaWduIG52LXNhMSgwJgYDVQQDEx9HbG9iYWxTaWduIFRpbWVzdGFt
# cGluZyBDQSAtIEcyMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAlO9l
# +LVXn6BTDTQG6wkft0cYasvwW+T/J6U00feJGr+esc0SQW5m1IGghYtkWkYvmaCN
# d7HivFzdItdqZ9C76Mp03otPDbBS5ZBb60cO8eefnAuQZT4XljBFcm05oRc2yrmg
# jBtPCBn2gTGtYRakYua0QJ7D/PuV9vu1LpWBmODvxevYAll4d/eq41JrUJEpxfz3
# zZNl0mBhIvIG+zLdFlH6Dv2KMPAXCae78wSuq5DnbN96qfTvxGInX2+ZbTh0qhGL
# 2t/HFEzphbLswn1KJo/nVrqm4M+SU4B09APsaLJgvIQgAIMboe60dAXBKY5i0Eex
# +vBTzBj5Ljv5cH60JQIDAQABo4HlMIHiMA4GA1UdDwEB/wQEAwIBBjASBgNVHRMB
# Af8ECDAGAQH/AgEAMB0GA1UdDgQWBBRG2D7/3OO+/4Pm9IWbsN1q1hSpwTBHBgNV
# HSAEQDA+MDwGBFUdIAAwNDAyBggrBgEFBQcCARYmaHR0cHM6Ly93d3cuZ2xvYmFs
# c2lnbi5jb20vcmVwb3NpdG9yeS8wMwYDVR0fBCwwKjAooCagJIYiaHR0cDovL2Ny
# bC5nbG9iYWxzaWduLm5ldC9yb290LmNybDAfBgNVHSMEGDAWgBRge2YaRQ2XyolQ
# L30EzTSo//z9SzANBgkqhkiG9w0BAQUFAAOCAQEATl5WkB5GtNlJMfO7FzkoG8IW
# 3f1B3AkFBJtvsqKa1pkuQJkAVbXqP6UgdtOGNNQXzFU6x4Lu76i6vNgGnxVQ380W
# e1I6AtcZGv2v8Hhc4EvFGN86JB7arLipWAQCBzDbsBJe/jG+8ARI9PBw+DpeVoPP
# PfsNvPTF7ZedudTbpSeE4zibi6c1hkQgpDttpGoLoYP9KOva7yj2zIhd+wo7AKvg
# IeviLzVsD440RZfroveZMzV+y5qKu0VN5z+fwtmK+mWybsd+Zf/okuEsMaL3sCc2
# SI8mbzvuTXYfecPlf5Y1vC0OzAGwjn//UYCAp5LUs0RGZIyHTxZjBzFLY7Df8zCC
# BJ8wggOHoAMCAQICEhEh1pmnZJc+8fhCfukZzFNBFDANBgkqhkiG9w0BAQUFADBS
# MQswCQYDVQQGEwJCRTEZMBcGA1UEChMQR2xvYmFsU2lnbiBudi1zYTEoMCYGA1UE
# AxMfR2xvYmFsU2lnbiBUaW1lc3RhbXBpbmcgQ0EgLSBHMjAeFw0xNjA1MjQwMDAw
# MDBaFw0yNzA2MjQwMDAwMDBaMGAxCzAJBgNVBAYTAlNHMR8wHQYDVQQKExZHTU8g
# R2xvYmFsU2lnbiBQdGUgTHRkMTAwLgYDVQQDEydHbG9iYWxTaWduIFRTQSBmb3Ig
# TVMgQXV0aGVudGljb2RlIC0gRzIwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK
# AoIBAQCwF66i07YEMFYeWA+x7VWk1lTL2PZzOuxdXqsl/Tal+oTDYUDFRrVZUjtC
# oi5fE2IQqVvmc9aSJbF9I+MGs4c6DkPw1wCJU6IRMVIobl1AcjzyCXenSZKX1GyQ
# oHan/bjcs53yB2AsT1iYAGvTFVTg+t3/gCxfGKaY/9Sr7KFFWbIub2Jd4NkZrItX
# nKgmK9kXpRDSRwgacCwzi39ogCq1oV1r3Y0CAikDqnw3u7spTj1Tk7Om+o/SWJMV
# TLktq4CjoyX7r/cIZLB6RA9cENdfYTeqTmvT0lMlnYJz+iz5crCpGTkqUPqp0Dw6
# yuhb7/VfUfT5CtmXNd5qheYjBEKvAgMBAAGjggFfMIIBWzAOBgNVHQ8BAf8EBAMC
# B4AwTAYDVR0gBEUwQzBBBgkrBgEEAaAyAR4wNDAyBggrBgEFBQcCARYmaHR0cHM6
# Ly93d3cuZ2xvYmFsc2lnbi5jb20vcmVwb3NpdG9yeS8wCQYDVR0TBAIwADAWBgNV
# HSUBAf8EDDAKBggrBgEFBQcDCDBCBgNVHR8EOzA5MDegNaAzhjFodHRwOi8vY3Js
# Lmdsb2JhbHNpZ24uY29tL2dzL2dzdGltZXN0YW1waW5nZzIuY3JsMFQGCCsGAQUF
# BwEBBEgwRjBEBggrBgEFBQcwAoY4aHR0cDovL3NlY3VyZS5nbG9iYWxzaWduLmNv
# bS9jYWNlcnQvZ3N0aW1lc3RhbXBpbmdnMi5jcnQwHQYDVR0OBBYEFNSihEo4Whh/
# uk8wUL2d1XqH1gn3MB8GA1UdIwQYMBaAFEbYPv/c477/g+b0hZuw3WrWFKnBMA0G
# CSqGSIb3DQEBBQUAA4IBAQCPqRqRbQSmNyAOg5beI9Nrbh9u3WQ9aCEitfhHNmmO
# 4aVFxySiIrcpCcxUWq7GvM1jjrM9UEjltMyuzZKNniiLE0oRqr2j79OyNvy0oXK/
# bZdjeYxEvHAvfvO83YJTqxr26/ocl7y2N5ykHDC8q7wtRzbfkiAD6HHGWPZ1BZo0
# 8AtZWoJENKqA5C+E9kddlsm2ysqdt6a65FDT1De4uiAO0NOSKlvEWbuhbds8zkSd
# wTgqreONvc0JdxoQvmcKAjZkiLmzGybu555gxEaovGEzbM9OuZy5avCfN/61PU+a
# 003/3iCOTpem/Z8JvE3KGHbJsE2FUPKA0h0G9VgEB7EYMIIFBTCCA+2gAwIBAgIR
# AN34yZVMJCxxAAAAAFVmcn0wDQYJKoZIhvcNAQELBQAwgbQxCzAJBgNVBAYTAlVT
# MRYwFAYDVQQKEw1FbnRydXN0LCBJbmMuMSgwJgYDVQQLEx9TZWUgd3d3LmVudHJ1
# c3QubmV0L2xlZ2FsLXRlcm1zMTkwNwYDVQQLEzAoYykgMjAxNSBFbnRydXN0LCBJ
# bmMuIC0gZm9yIGF1dGhvcml6ZWQgdXNlIG9ubHkxKDAmBgNVBAMTH0VudHJ1c3Qg
# Q29kZSBTaWduaW5nIENBIC0gT1ZDUzEwHhcNMTgwOTA1MDIzOTM5WhcNMjEwOTEy
# MDMwOTMxWjBiMQswCQYDVQQGEwJVUzETMBEGA1UECBMKQ2FsaWZvcm5pYTESMBAG
# A1UEBxMJU3Vubnl2YWxlMRQwEgYDVQQKEwtOZXRBcHAsIEluYzEUMBIGA1UEAxML
# TmV0QXBwLCBJbmMwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDWrmpV
# PJjNhxp6jIBrptRNjIu08S/iHcnQKwzlCEroO/vhJ3zMTmF6WBNv7ytNljEL2PT9
# eAu4T2f5S/OIBKT4wBtdu9PZ9rkrXa3V4dJvpGb0LLMWLxsYiMluRGfH6+i1Q31J
# B/RFGhbMwqE7XFlVCN0X9vDQcFZd2tnoNXn06wkvvBTV+z6wcztzNwchzK3X25cL
# CIw5g3YlAtmNZ4pV4s1vmSQFi2UyGs5Jo+DVknihYtY79gCDTNjwIlgCgQFD/aer
# FjF4SFZHX9EmYB8CqRroRHro4OlPxlQtRuLxMJU0Ezw+mPqdaoBc7FCcHLpL6w7Y
# pkYUzJWak3Ik2vLvAgMBAAGjggFhMIIBXTAOBgNVHQ8BAf8EBAMCB4AwEwYDVR0l
# BAwwCgYIKwYBBQUHAwMwagYIKwYBBQUHAQEEXjBcMCMGCCsGAQUFBzABhhdodHRw
# Oi8vb2NzcC5lbnRydXN0Lm5ldDA1BggrBgEFBQcwAoYpaHR0cDovL2FpYS5lbnRy
# dXN0Lm5ldC9vdmNzMS1jaGFpbjI1Ni5jZXIwMQYDVR0fBCowKDAmoCSgIoYgaHR0
# cDovL2NybC5lbnRydXN0Lm5ldC9vdmNzMS5jcmwwTAYDVR0gBEUwQzA3BgpghkgB
# hvpsCgEDMCkwJwYIKwYBBQUHAgEWG2h0dHA6Ly93d3cuZW50cnVzdC5uZXQvcnBh
# IDAIBgZngQwBBAEwHwYDVR0jBBgwFoAUfhofGhF0XGTJDB+UAav9gWQuoSwwHQYD
# VR0OBBYEFCH1vtDASHXz9CannsItGaIK5uANMAkGA1UdEwQCMAAwDQYJKoZIhvcN
# AQELBQADggEBADec32dI/RZxfq7+0kKVA+Ua4whPLy2+4wPxf+ThI3afgZAEG6J2
# 7F8y1Q8HctsKYm2rBKzxXh1YY5Vl+R3tznnlpGEmyTfuo/ZobGnMQtfbWcZtPamH
# cxBkmXTitfYA+03Bf54YYkW8yAi5X3d930OEifP/UMLjdYhNbdK6iyPNk6WHDOf8
# 2julmAPt6BS+69PugbUtMwuyXuk7XCOI9gOHyMbCKXyCfuWyY6TJuBhDjPXDlnum
# lnGwLZAX5VQONrO4meNZiN4AKcoJ3rkws/HvGCFsGyG3b1btQfwbhwKsCO+xtCYG
# 2TJ1r3T3kkZXr1yjSUUs+JVYXP4q5vTz5F4wggUdMIIEBaADAgECAgxDwQscAAAA
# AFHTc9owDQYJKoZIhvcNAQELBQAwgb4xCzAJBgNVBAYTAlVTMRYwFAYDVQQKEw1F
# bnRydXN0LCBJbmMuMSgwJgYDVQQLEx9TZWUgd3d3LmVudHJ1c3QubmV0L2xlZ2Fs
# LXRlcm1zMTkwNwYDVQQLEzAoYykgMjAwOSBFbnRydXN0LCBJbmMuIC0gZm9yIGF1
# dGhvcml6ZWQgdXNlIG9ubHkxMjAwBgNVBAMTKUVudHJ1c3QgUm9vdCBDZXJ0aWZp
# Y2F0aW9uIEF1dGhvcml0eSAtIEcyMB4XDTE1MDYxMDEzNDYwNVoXDTMwMTExMDE0
# MTYwNVowgbQxCzAJBgNVBAYTAlVTMRYwFAYDVQQKEw1FbnRydXN0LCBJbmMuMSgw
# JgYDVQQLEx9TZWUgd3d3LmVudHJ1c3QubmV0L2xlZ2FsLXRlcm1zMTkwNwYDVQQL
# EzAoYykgMjAxNSBFbnRydXN0LCBJbmMuIC0gZm9yIGF1dGhvcml6ZWQgdXNlIG9u
# bHkxKDAmBgNVBAMTH0VudHJ1c3QgQ29kZSBTaWduaW5nIENBIC0gT1ZDUzEwggEi
# MA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDYhg2gZApq9Y6WujuaaGrbREDe
# 9S38621EWM+OcsNwLV5a1PkL2BE1l8Ap8TvuF6HWRLm/H0qY4BkOteNZCB1SjKCw
# iihBpKGGQFCzTceIQdo2k6dMPWMsA8uvjQAlEWlQIvZLAM7Dsi6Bhd0j3U5NtfDA
# qHT862xgKZhxj2j3tx3z+EOLYpUyhk/KyExLU/5RIDAe/wBEx15xmqUbiXRK/lM+
# hOqxo4md+C1CWNgKBlAjcBYcAneXGDzZEH0MeuYFLBoIFmYSOGxxHdZk11bAjTbD
# uLUAuN0vtXq/saRuePptEnbkmXcRpiTkgrlGeamwo0lb01N0Q4F0b6H4Li8lAgMB
# AAGjggEhMIIBHTAOBgNVHQ8BAf8EBAMCAQYwEwYDVR0lBAwwCgYIKwYBBQUHAwMw
# EgYDVR0TAQH/BAgwBgEB/wIBADAzBggrBgEFBQcBAQQnMCUwIwYIKwYBBQUHMAGG
# F2h0dHA6Ly9vY3NwLmVudHJ1c3QubmV0MDAGA1UdHwQpMCcwJaAjoCGGH2h0dHA6
# Ly9jcmwuZW50cnVzdC5uZXQvZzJjYS5jcmwwOwYDVR0gBDQwMjAwBgRVHSAAMCgw
# JgYIKwYBBQUHAgEWGmh0dHA6Ly93d3cuZW50cnVzdC5uZXQvcnBhMB0GA1UdDgQW
# BBR+Gh8aEXRcZMkMH5QBq/2BZC6hLDAfBgNVHSMEGDAWgBRqciZ60B7vfec7aVHU
# bI2fkBJmqzANBgkqhkiG9w0BAQsFAAOCAQEAt3RntD5MJS9iNYGc0nblp+IoeHTD
# 7BnlE/m2I5RPYqdM5k5ywiSQ0Hm6qM3XRN8AOTDxKMRyb3iskAsto+qFrRTCCxSZ
# P/sjdK2oqswiYzIlASvK0BZGQlqnREdYHQRB4tExvpdhO64EGGx6eoFfqyL+CNY1
# jqcN9ewg3Nxtx6J22PtmqEMDASGooPZM5tSCztcNAdYzrJCj4JK7GAJ1QwJ6BLTY
# Fe1XkTwS541m+L0UzEaC1voDwAoNfLGAD+uhGjaldR882Drq55WB3qxa+521zBFO
# KnQR1n95QmHKIUFgHqTd8dl0sNWl6AtMgYnfzIYWJRmlFFeVoooie7FljTGCBRIw
# ggUOAgEBMIHKMIG0MQswCQYDVQQGEwJVUzEWMBQGA1UEChMNRW50cnVzdCwgSW5j
# LjEoMCYGA1UECxMfU2VlIHd3dy5lbnRydXN0Lm5ldC9sZWdhbC10ZXJtczE5MDcG
# A1UECxMwKGMpIDIwMTUgRW50cnVzdCwgSW5jLiAtIGZvciBhdXRob3JpemVkIHVz
# ZSBvbmx5MSgwJgYDVQQDEx9FbnRydXN0IENvZGUgU2lnbmluZyBDQSAtIE9WQ1Mx
# AhEA3fjJlUwkLHEAAAAAVWZyfTAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEK
# MAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3
# AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUdDz8AE703cFUWgo2
# I+oSnFs26cQwDQYJKoZIhvcNAQEBBQAEggEAVwR3Vx9Whj64P8pE35NEH6GBAZaA
# 2LRxt3Jn045Vs7er6CDKa2rOGyswTrrzq24SSeyYm8v6JzojzaUHuhWJ7ra5y5Hq
# dNQEncn82Ejme7ckPL+viVAFmF4bM603cNdBk8ytts78a6YVpVVDK90Z+HtDIO6z
# 6TNI4cbfE27+2yr9MJxmljhwFugmICNPCLMe3TKZj7BdmjT3bXu0qmqNB5zEnZzS
# Y6unQppZNMlE2xu90NWmpoSU0aRUdmFn3k/RnAJvItKf/HNITpm27h0LjkY6gMc8
# OicotBcHXqzV22ExQMp17JTTJ9+BKgG0OdWqrDMQxL1Bc7nGL222kquAgaGCAqIw
# ggKeBgkqhkiG9w0BCQYxggKPMIICiwIBATBoMFIxCzAJBgNVBAYTAkJFMRkwFwYD
# VQQKExBHbG9iYWxTaWduIG52LXNhMSgwJgYDVQQDEx9HbG9iYWxTaWduIFRpbWVz
# dGFtcGluZyBDQSAtIEcyAhIRIdaZp2SXPvH4Qn7pGcxTQRQwCQYFKw4DAhoFAKCB
# /TAYBgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0xODA5
# MTUwMDI5MjhaMCMGCSqGSIb3DQEJBDEWBBTvUn60rgJmfs1beWy1mJdAwArTqjCB
# nQYLKoZIhvcNAQkQAgwxgY0wgYowgYcwgYQEFGO4L6th9YOQlpUFCwAknFApM+x5
# MGwwVqRUMFIxCzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNh
# MSgwJgYDVQQDEx9HbG9iYWxTaWduIFRpbWVzdGFtcGluZyBDQSAtIEcyAhIRIdaZ
# p2SXPvH4Qn7pGcxTQRQwDQYJKoZIhvcNAQEBBQAEggEApru4SUY6ZiiWSY6XSVX5
# C8ezCMiITucg1kSHjFLdDEBpiSRz2bzG2DYpm0WKOwg0GNBSpncRg9Dc+qbBFDfA
# xwReNOZ98yWT3ybDIwNDQWRkpn14h08auopcsQbl0abiFZoWsxBAARY5kLlqYafH
# 493aP7apuRav/iNPi+qlv+sXSYBYeZykoT/SUbyX8f4pR47nllswhYixqhq4Pb7+
# ztZujrd/vY3S1upOO8rjHN1FO/c+DRdgVx4ZonGkn77S0zvqXnelJijxpllaQ0uJ
# A6OM9gZl07I/PuGdAd6X4cEejtYlOzXt3cbfY1e3wGLiqX994bQPSm8kHQdPqxmQ
# tg==
# SIG # End signature block

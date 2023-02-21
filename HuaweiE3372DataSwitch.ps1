########################################################
######                                             #####
######              Functions                      #####
######                                             #####
########################################################
function Log($Message, $Type = 0){
#$Type = 0 - Info; $Type = 1 - Error    
    if ($Type -eq 0){
        Write-Host $Message
    }elseif ($Type -eq 1){
        Write-Error $Message
        $Message = "ERROR: $Message"
    }
    return "$Message`r`n"
}

function Get-SessionIDandToken($IPModem){
    $res = Invoke-WebRequest -UseBasicParsing -Uri "http://$ipModem/html/home.html"
    if ($res.StatusCode -eq 200){
        $token = [System.Text.RegularExpressions.Regex]::Matches($res.Content, "(csrf_token).*\/")[0].Value.Split("`"")
        $sesID = $res.Headers["Set-Cookie"]
        return @{
            "SessionID" = $sesID.Substring("SessionID=".Length, $sesID.IndexOf(';') - "SessionID=".Length)
            "Token" = $token[2]
            }
    }
    return $null
}
########################################################
if($args.Count -eq 0){
    Write-Error "Необхідно вказати параметр: 0 - Off; 1 - On"
    Exit -1
}
########################################################
$ipModem = "192.168.8.1"
$log = Log("Початок роботи скрипта: $([datetime]::Now.ToString('yyyy-MM-dd HH:mm:ss'))")
$emlFrom = "e-mail from"
$emlTo = "e-mail to"
$emlPass = "password to smtp server"
$exCode = 0
########################################################
if ( -not ($args[0] -eq "0" -or $args[0] -eq "1")){
    $log += Log("Помилка в параметрах скрипта.`r`nСкрипт приймає 0 (відключити моб. дані) або 1 (підключити моб. дані).Наприклад,`r`n powershell d:\Programs\Scripts\HuaweiE3372DataSwitch.ps1 0", 1)
    $exCode = -1
}else{
    #Try connect to website of modem and get cookie
    $log += Log("Отримання SessionID та VerificationToken...")
    $sessID = Get-SessionIDandToken($ipModem)
    if ($sessID -eq $null){
        $log += Log("Не вдалося отримати SessionID та VerificationToken", 1)
        $exCode = -11
    }else{ 
        $log += Log("... отримано`r`nDataSwitch:: set $($args[0])")
        $body="<?xml version='1.0' encoding='UTF-8'?><request><dataswitch>$($args[0])</dataswitch></request>"
        $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
        $session.Cookies.Add((New-Object System.Net.Cookie("SessionID", $sessID.SessionID, "/", $ipModem)))
        $res = Invoke-WebRequest -Uri "http://$ipModem/api/dialup/mobile-dataswitch" -WebSession $session -Body $body -Method Post `
        -Headers @{
            "Accept"="*/*"
            "Content-Type"="text/xml"
            "__RequestVerificationToken"=$sessID.Token
        }
        if (-not $res.Content.Contains("<response>OK")){
            $log += Log("Помилка при виконанні запиту до модема. Спробуйте знову.`r`n$($res.Content)", 1)
            $exCode = -3
        }else{
            $log += Log("Успіх.`r`nДля перевірки статусу >> http://$ipModem/html/home.html")
        }
    }
}
#Send result to support@vkutkxp.com.ua
$secpasswd = ConvertTo-SecureString $emlPass -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential($emlFrom, $secpasswd)
Write-Host "Send log to e-mail"
Send-MailMessage -To $emlTo -From $emlFrom -Subject "HuaweiE3372::Mobile dataswitch" -Body $log -SmtpServer "smtp-server" -Credential $cred -Encoding $([System.Text.UTF8Encoding]::UTF8)
Start-Sleep -Seconds 3
Exit $exCode
#

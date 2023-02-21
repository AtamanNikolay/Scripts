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
$secpasswd = ConvertTo-SecureString "01000000d08c9ddf0115d1118c7a00c04fc297eb01000000e3514b6fab83944e9da418686734fb680000000002000000000010660000000100002000000020f2f5b976002626aa33d9f55b28570cdb7376e461e66176f627604146abe047000000000e8000000002000020000000cf58f8bb8612bae24b66ee6d10201e3ff4c9bcd56980b12f35983dc2e16d460020000000e2b1748d6f3b36e3ef46dcd73c5fe8f4c94252602d50d5152f6c89bd5ea447aa40000000c71e2d8d4d03d16b3e4c34da89793a4644c7ea26a4b3607563aeed92feaac39e5640f66b9fd5193e2d08b192b30673442307604131e3eeac24fd17717563a0b3"# -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential("support@vkutkxp.com.ua", $secpasswd)
Write-Host "Send log to e-mail"
Send-MailMessage -To "support@vkutkxp.com.ua" -From "support@vkutkxp.com.ua" -Subject "HuaweiE3372::Mobile dataswitch" -Body $log -SmtpServer "192.168.12.207" -Credential $cred -Encoding $([System.Text.UTF8Encoding]::UTF8)
Start-Sleep -Seconds 3
Exit $exCode
#

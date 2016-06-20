$date = Get-Date -Format dd.MM.yyyy 

New-Item -Path "\\BACKUP-SERVER\SYSTEMSTATE\$data" -ItemType directory
New-Item -Path "C:\LOG\SYSTEMSTATE\$data" -ItemType directory

wbadmin start systemstatebackup -backupTarget:$backdir | Out-File C:\LOG\SYSTEMSTATE\$data\log-systemstate.txt

$filename = “C:\LOG\SYSTEMSTATE\$data\log-systemstate.txt”
$smtpServer = “smtpserver.com.br”
$msg = new-object Net.Mail.MailMessage
$att = new-object Net.Mail.Attachment($filename)
$smtp = new-object Net.Mail.SmtpClient($smtpServer)
$smtp.Credentials = New-Object Net.NetworkCredential(“exemplo@exemplo.com”, “SENHA”)
$msg.From = “exemplo@exemplo.comr”
$msg.To.Add(“exemplo@exemplo.com”)
$date = get-date
$msg.Subject = “BACKUP GPOS – $date”
$msg.Body = “BACKUP DA SYSTEMSTATE CONCLUÍDO. VERIFIQUE O LOG EM ANEXO PARA CERTIFICAR QUE NÃO HOUVE ERRO.”
$msg.Attachments.Add($att)
$smtp.Send($msg)
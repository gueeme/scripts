$data = Get-Date -Format dd.MM.yyyy
$nome = "$data"
New-Item -Path "\\BACKUP-SERVER\GPOs\$data" -ItemType directory
New-Item -Path "C:\LOG\GPOS\$data" -ItemType directory

Backup-GPO -Path "\\BACKUP-SERVER\GPOs\$data" -All -Server SERVERNAME.domain.local | Out-File C:\LOG\GPOS\$data\log-gpo.txt

$filename = “C:\LOG\GPOS\$data\log-gpo.txt”
$smtpServer = “smtpserver.com.br”
$msg = new-object Net.Mail.MailMessage
$att = new-object Net.Mail.Attachment($filename)
$smtp = new-object Net.Mail.SmtpClient($smtpServer)
$smtp.Credentials = New-Object Net.NetworkCredential(“exemplo@exemplo.com”, “SENHA”)
$msg.From = “exemplo@exemplo.com”
$msg.To.Add(“exemplo@exemplo.com”)
$date = get-date
$msg.Subject = “BACKUP GPOS – $date”
$msg.Body = “BACKUP DE GPOS CONCLUÍDO. VERIFIQUE O LOG EM ANEXO PARA CERTIFICAR QUE NÃO HOUVE ERRO.”
$msg.Attachments.Add($att)
$smtp.Send($msg)

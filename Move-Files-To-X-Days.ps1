get-childitem -Path "\\servername\location" |
    where-object {$_.LastWriteTime -lt (get-date).AddDays(-31)} |
    move-item -destination "C:\Dumps"

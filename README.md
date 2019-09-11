# PSSQLBackup
The Microsoft SQL Server Backup module allows to take backup of your MS SQL Databases, search for backups and remove if necessary.
You can backup multiple databases at once, remove and search for already taken backups.

All functions support multiple searches, backup and remove. You can e.g. search for previous backups and get the output as objects 
with properties like Database name, backup taken, file name and so on. 
You can then pipe those objects to Remove-PSSQLBackup and remove if necessary.

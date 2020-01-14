# PSSQLBackup
The Microsoft SQL Server Backup module allows to take backup of your MS SQL Databases, search for backups and remove if necessary.
You can backup multiple databases at once, remove and search for already taken backups.
Some of the main features of PSSQLBackup are:

  * Get all previous SQL Backups
  * Create new backup of multiple databases
  * Remove previous backups

All functions support multiple searches, backup & remove. You can e.g. search for previous backups and get the output as objects 
with properties like database name, backup date, file name and so on and pipe it to remove-pssqlbackup which will remove all defined backups.


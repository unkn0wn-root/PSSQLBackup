# PSSQLBackup
The SQL Server Backup module allows to take backup of your SQL Databases, search for backups and remove if necessary.
You can backup multiple databases at once, remove and search for already taken backups.

All functions support multiple searches, backup and remove. You can e.g. search for previous backups and get the output as objects 
with properties like Database name, backup taken, file name and so on. 
You can then pipe those objects to Remove-PSSQLBackup and remove if necessary.


# Important
This is version 1.0 which can have some bugs and issues. Before you decide to use this module in production, 
I strongly recommend to run this module on the test site.
Create pull request if you have any comments and give feedback so I can fix all issues right away.

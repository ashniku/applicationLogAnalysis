# applicationLogAnalysis
Provide a detailed report on the phases that took time and also will provide hints on the issue on that phase.

Follow below steps on MAC:

Split the application using yarn splitter.

Follow https://github.com/TarunParimi/yarn-log-splitter to split the application

Install brew and dateutils package in MAC

brew install dateutils

Download the script attached and provide full permission

chmod 777 application_stats.sh

Navigate to containers/<application master container that ends with 001>

Execute

sh application_stats.sh sysdag

Please use the correct syslog_dag if there are multiple syslog_dag

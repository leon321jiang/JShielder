#!/bin/bash
#
#1. log bash command to syslog
#2. add osquery to syslog
#3. install osquery
#4. install aws inspector


##############################################################################################################

check_root() {
if [ $EUID -ne 0 ]; then
      echo "Permission Denied"
      echo "Can only be run by root"
      exit
else
      clear
fi
}

check_root


##### 
# log bash command to syslog, this need to restart syslog services to work 
cat <<EOT3 >> /etc/profile
function log2syslog
{
   declare COMMAND
   COMMAND=$(fc -ln -0)
   logger -p local1.notice -t bash -i -- "${USER}:${COMMAND}"
}
trap log2syslog DEBUG
EOT3
############

###
# add osquery log to remote log, need to change the last line for log destination if change environments

cat <<EOT4 >> /etc/rsyslog.conf
#############
#Following section is about osquery log file
#query result 
\$ModLoad imfile
\$InputFileName /var/log/osquery/osqueryd.results.log
\$InputFileTag osquery-result
\$InputFileStateFile osquery-result
\$InputFileSeverity info
\$InputFileFacility local6
\$InputRunFileMonitor

# info

\$InputFileName /var/log/osquery/osqueryd.INFO
\$InputFileTag osquery-info
\$InputFileStateFile osquery-info
\$InputFileSeverity notice
\$InputFileFacility local6
\$InputRunFileMonitor

#warning

\$InputFileName /var/log/osquery/osqueryd.WARNING
\$InputFileTag osquery-warning
\$InputFileStateFile osquery-warning
\$InputFileSeverity warning
\$InputFileFacility local6
\$InputRunFileMonitor


#end of osquery log config
#################
EOT4


#NOT locally store osquery as syslog
cat <<EOT5 >> /etc/rsyslog.d/50-default.conf
local6.none -/var/log/osquery/syslog
EOT5


service syslog restart
service rsyslog restart

## increase inotify # for osquery file monitoring
echo fs.inotify.max_user_watches=70912 >> /etc/sysctl.conf && sysctl -p

############
# This is to install and configure osquery 

export OSQUERY_KEY=1484120AC4E9F8A1A577AEEE97A80C63C9D8B80B
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys $OSQUERY_KEY
sudo add-apt-repository 'deb [arch=amd64] https://pkg.osquery.io/deb deb main'
sudo apt-get update
sudo apt-get install osquery

cat <<'EOT' >> /etc/rsyslog.conf 
template(
  name="OsqueryCsvFormat"
  type="string"
  string="%timestamp:::date-rfc3339,csv%,%hostname:::csv%,%syslogseverity:::csv%,%syslogfacility-text:::csv%,%syslogtag:::csv%,%msg:::csv%\n"
)
*.* action(type="ompipe" Pipe="/var/osquery/syslog_pipe" template="OsqueryCsvFormat")
EOT

systemctl restart rsyslog


#file integration monitoring
cat <<'EOT2' >> /usr/share/osquery/packs/fim.conf
{
  "queries": {
    "file_events": {
      "query": "select * from file_events;",
      "removed": false,
      "interval": 3600
    }
  },
  "file_paths": {
    "homes": [
      "/root/.ssh/%%",
      "/home/%/.ssh/%%"
    ],
      "etc": [
      "/etc/%%"
    ],
      "home": [
      "/home/%%"
    ],
      "tmp": [
      "/tmp/%%"
    ]
  }
}
EOT2

cat <<'EOT1' >> /etc/osquery/osquery.conf
{
  "options": {
    "config_plugin": "filesystem",
    "logger_plugin": "filesystem",
    "logger_path": "/var/log/osquery",
    "disable_logging": "false",
    "log_result_events": "true",
    "schedule_splay_percent": "10",
    "pidfile": "/var/osquery/osquery.pidfile",
    "events_expiry": "3600",
    "database_path": "/var/osquery/osquery.db",
    "verbose": "false",
    "worker_threads": "2",
    "enable_monitor": "true",
    "disable_events": "false",
    "disable_audit": "false",
    "audit_allow_config": "true",
    "host_identifier": "hostname",
    "enable_syslog": "true",
    "audit_allow_sockets": "true",
    "schedule_default_interval": "86400" 
  },
  "schedule": {
    "crontab": {
      "query": "SELECT * FROM crontab;",
      "interval": 86400
    }
  },
  "decorators": {
    "load": [
      "SELECT uuid AS host_uuid FROM system_info;",
      "SELECT user AS username FROM logged_in_users ORDER BY time DESC LIMIT 1;"
    ]
  },
  "packs": {
     "fim": "/usr/share/osquery/packs/fim.conf",
     "osquery-monitoring": "/usr/share/osquery/packs/osquery-monitoring.conf",
     "incident-response": "/usr/share/osquery/packs/incident-response.conf",
     "it-compliance": "/usr/share/osquery/packs/it-compliance.conf",
     "vuln-management": "/usr/share/osquery/packs/vuln-management.conf"
  }
}
EOT1

chmod 644 osqueryd.results.log

osqueryctl config-check
systemctl enable osqueryd.service
systemctl start osqueryd

#################
# install AWS inspector 
curl -O https://d1wk0tztpsntt1.cloudfront.net/linux/latest/install

bash install

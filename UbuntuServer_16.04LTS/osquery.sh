#!/bin/bash

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

sudo systemctl restart rsyslog


#file integration monitoring
cat <<'EOT2' >> /usr/share/osquery/packs/fim.conf
{
  "queries": {
    "file_events": {
      "query": "select * from file_events;",
      "removed": false,
      "interval": 300
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
    "schedule_default_interval": "3600" 
  },
  "schedule": {
    "crontab": {
      "query": "SELECT * FROM crontab;",
      "interval": 28800
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

sudo osqueryctl config-check

sudo systemctl start osqueryd

#################
# install AWS inspector 
curl -O https://d1wk0tztpsntt1.cloudfront.net/linux/latest/install

sudo bash install

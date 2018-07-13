#!/bin/bash

## log bash command to syslog 

cat <<EOT3 >> /etc/profile
function log2syslog
{
   declare COMMAND
   COMMAND=$(fc -ln -0)
   logger -p local1.notice -t bash -i -- "${USER}:${COMMAND}"
}
trap log2syslog DEBUG
EOT3

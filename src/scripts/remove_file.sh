#!/bin/bash
### BEGIN INIT INFO
# Provides:          remove_file
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Remove specific files at startup
# Description:       This script removes specific files at startup.
### END INIT INFO

FILES_TO_REMOVE=(
  "/etc/ssh/sshd_config.d/60-cloudimg-settings.conf"
  "/etc/ssh/sshd_config.d/50-cloud-init.conf"
)

case "$1" in
  start)
    for FILE in "${FILES_TO_REMOVE[@]}"; do
      if [ -f "$FILE" ]; then
        rm -f "$FILE"
        echo "Removed $FILE"
      fi
    done
    ;;
  stop)
    # No-op
    ;;
  *)
    echo "Usage: /etc/init.d/remove_file.sh {start|stop}"
    exit 1
    ;;
esac

exit 0
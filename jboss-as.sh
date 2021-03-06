#!/bin/bash
#
# JBoss standalone control script
#
# Based on the file provided in JBoss AS 7.1.1 (https://github.com/jbossas/jboss-as/blob/master/build/src/main/resources/bin/init.d/jboss-as-standalone.sh)
# inspired by http://stackoverflow.com/questions/6880902/start-jboss-7-as-a-service-on-linux and http://ptoconnor.wordpress.com/2012/11/19/jboss-as-7-1-1-on-an-ubuntu-12-04-aws-instance-running-oracle-java-7/
# Modified for Ubuntu Server 12.04 by Anthony O.
#
# chkconfig: - 80 20
# description: JBoss AS Standalone
# config: /etc/default/jboss-as-7
#
### BEGIN INIT INFO
# Provides:          jboss-as
# Required-Start:    $local_fs $remote_fs $network
# Required-Stop:     $local_fs $remote_fs $network
# Should-Start:      $named
# Should-Stop:       $named
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start JBoss AS
# Description:       Start JBoss Application Server.
### END INIT INFO
#

JBOSS_CONF="/etc/jboss-npe/jboss-as.conf"

# Parameters passed to the standalone.sh
SCRIPT_PARAMS="-b=0.0.0.0 -bmanagement=0.0.0.0"

NAME=jboss-as
DEFAULT=/etc/default/$NAME

# Source function library.
. /lib/lsb/init-functions

# Load Java configuration.
# Ubuntu has it in /etc/default
[ -r /etc/default/java ] && . /etc/default/java
export JAVA_HOME

# Load JBoss AS init.d configuration.
if [ -z "$JBOSS_CONF" ]; then
  JBOSS_CONF=$DEFAULT
fi

[ -r "$JBOSS_CONF" ] && . "${JBOSS_CONF}"

# Set defaults.

if [ -z "$JBOSS_HOME" ]; then
#  JBOSS_HOME="/opt/$NAME"
  JBOSS_HOME="/opt/jboss-eap-6.2"
fi
export JBOSS_HOME

if [ -z "$JBOSS_USER" ]; then
#  JBOSS_USER="jboss-as"
  JBOSS_USER="jboss"
fi
export JBOSS_USER

if [ -z "$JBOSS_PIDFILE" ]; then
  JBOSS_PIDFILE=/var/run/$NAME/jboss-as-standalone.pid
fi
export JBOSS_PIDFILE

if [ -z "$JBOSS_CONSOLE_LOG" ]; then
#  JBOSS_CONSOLE_LOG=/var/log/$NAME/console.log
  JBOSS_CONSOLE_LOG=/var/log/$NAME/server.log
fi

# We need this to be set to get a pidfile !
if [ -z "$LAUNCH_JBOSS_IN_BACKGROUND" ]; then
  LAUNCH_JBOSS_IN_BACKGROUND=true
fi
export LAUNCH_JBOSS_IN_BACKGROUND

if [ -z "$STARTUP_WAIT" ]; then
  STARTUP_WAIT=120
fi

if [ -z "$SHUTDOWN_WAIT" ]; then
  SHUTDOWN_WAIT=120
fi

if [ -z "$JBOSS_CONFIG" ]; then
  JBOSS_CONFIG=standalone.xml
fi

JBOSS_SCRIPT=$JBOSS_HOME/bin/standalone.sh

MATCHING_ARGS=(--user "$JBOSS_USER" --pidfile "$JBOSS_PIDFILE")

start() {
  log_daemon_msg "Starting $NAME"
  id $JBOSS_USER > /dev/null 2>&1
  if [ $? -ne 0 -o -z "$JBOSS_USER" ]; then
    log_failure_msg "User $JBOSS_USER does not exist..."
    log_end_msg 1
    exit 1
  fi

  mkdir -p $(dirname $JBOSS_CONSOLE_LOG)
  cat /dev/null > $JBOSS_CONSOLE_LOG
  chown $JBOSS_USER $JBOSS_CONSOLE_LOG

  mkdir -p $(dirname $JBOSS_PIDFILE)
  chown ${JBOSS_USER}: $(dirname $JBOSS_PIDFILE) || true

  if [ ! -z "$JBOSS_USER" ]; then
    start-stop-daemon --start ${MATCHING_ARGS[@]} --oknodo --chuid "$JBOSS_USER" --chdir "$JBOSS_HOME" --retry $STARTUP_WAIT $(if [ "$LAUNCH_JBOSS_IN_BACKGROUND" == "true" ] ; then echo "--background" ; fi) --startas /bin/bash -- -c "exec $JBOSS_SCRIPT $SCRIPT_PARAMS -c $JBOSS_CONFIG 2>&1 > $JBOSS_CONSOLE_LOG"
  else
    log_failure_msg "Error: Environment variable JBOSS_USER not set or empty."
    log_end_msg 1
    exit 1
  fi

  if [ "$LAUNCH_JBOSS_IN_BACKGROUND" == "true" ] ; then
    count=0
    launched_status=1

    until [ $count -gt $STARTUP_WAIT ]
    do
      grep 'JBAS015874:' $JBOSS_CONSOLE_LOG > /dev/null 
      if [ $? -eq 0 ] ; then
        launched_status=0
        break
      fi 
      sleep 1
      let count=$count+1;
    done

    log_end_msg $launched_status
    return $launched_status
  else
    log_end_msg $?
    return $?
  fi
}

stop() {
  log_daemon_msg "Stopping $NAME"

  END_STATUS=0
  if [ -f $JBOSS_PIDFILE ]; then
    start-stop-daemon --stop ${MATCHING_ARGS[@]} --retry $SHUTDOWN_WAIT
    END_STATUS=$?
    rm -f $JBOSS_PIDFILE
  fi
  log_end_msg $END_STATUS
  return $END_STATUS
}

status() {
  start-stop-daemon --status --verbose ${MATCHING_ARGS[@]}
  exit $?
}

reload() {
  log_begin_msg "Reloading $prog ..."
  start-stop-daemon --start --quiet --chuid ${JBOSS_USER} --exec ${JBOSS_HOME}/bin/jboss-cli.sh -- --connect command=:reload
  log_end_msg $?
  exit $?
}

case "$1" in
  start)
      start
      ;;
  stop)
      stop
      ;;
  restart)
      $0 stop
      $0 start
      ;;
  status)
      status
      ;;
  reload)
      reload
      ;;
  *)
      ## If no parameters are given, print which are avaiable.
      echo "Usage: $0 {start|stop|status|restart|reload}"
      exit 1
      ;;
esac

#!/bin/sh

USER="root"
PASS="123456"
MYSQLHOST="localhost"
SSHUSER="lubakka"
BACKUPSERVER="192.168.1.132"
BACKUPSERVERPATH="/BACKUP"
KEY="/home/lubakka/.ssh/id_rsa"
DESTMYSQL="/BACKUP/MySQL"
VAR="/var/www"
DESTVAR="/BACKUP/VAR"
SSH="$(which ssh)"
MYSQL="$(which mysql)"
MYSQLDUMP="$(which mysqldump)"
CHOWN="$(which chown)"
CHMOD="$(which chmod)"
GZIP="$(which gzip)"
IDUSERGROUP="$(id -g root)"
IDUSER="$(id -u root)"
HOSTNAME="$(hostname)"
MBD="$DESTMYSQL/$HOSTNAME"
VARD="$DESTVAR/$HOSTNAME"
NOW="$(date +"%d-%m-%Y")"

FILE=""
DB=""

RED='\033[0;31m'
NC='\033[0m'

IGNORE="'performance_schema' 'information_schema' "

mysqlDump() {
  [ "$(whoami)" != "root" ] && exec sudo -- "$0" "$@"
  MYSQLDUMPOPTIONS="--add-drop-database --add-drop-table -E -c --single-transaction"
  [ ! -d $MBD ] && sudo mkdir -p $MBD||:
  $CHOWN $IDUSER.$IDUSERGROUP -R $DESTMYSQL
  $CHMOD -R 0660 $DESTMYSQL
  if [ "$PASS" = "" ];
  then
    DB="$($MYSQL --user=$USER --host=$MYSQLHOST -Bse 'SHOW DATABASES;')"
  else
    DB="$($MYSQL --user=$USER --host=$MYSQLHOST --password=$PASS -Bse 'SHOW DATABASES;')"
  fi
  
  for db in $DB
  do
      local SKIPDB=0
      if [ "$IGNORE" != "" ];
      then
          for i in $IGNORE
          do
              [ "'$db'" = "$i" ] && local SKIPDB=1||:
          done
      fi
      if [ "$SKIPDB" = "0" ] ; then
          FILE="$MBD/$db.$HOSTNAME.$NOW.gz"

          if [ "$PASS" = "" ];
          then
            $MYSQLDUMP $MYSQLDUMPOPTIONS --user=$USER --host=$MYSQLHOST $db | $GZIP > $FILE
          else
            $MYSQLDUMP $MYSQLDUMPOPTIONS --user=$USER --host=$MYSQLHOST --password=$PASS $db | $GZIP > $FILE
          fi
      fi
  done
}

rsyncTO(){
  [ "$(whoami)" != "root" ] && exec sudo -- "$0" "$@"

  if [ "$KEY" != ""];
  	then
  		rsync -e "$SSH -i $KEY" -avzp  --progress --recursive --relative $DESTMYSQL $SSHUSER@$BACKUPSERVER:$BACKUPSERVERPATH
  	else
  		echo "${RED}Variable 'KEY' is required!${NC}"
  fi
}

varDump(){
  [ "$(whoami)" != "root" ] && exec sudo -- "$0" "$@"

  [ ! -d $VARD ] && sudo mkdir -p $VARD||:

  $CHOWN $IDUSER.$IDUSERGROUP -R $DESTVAR
  $CHMOD -R 0660 $DESTVAR

  rsync -avz $VAR $DESTVAR
}

usage() {
cat <<EOF
Usage: $0 <[options]>
Options:
        -i "databases"               Set which ignore databases.
        -m     --mysql               Backup mysql all databases.
        -h     --help                Show this message
        -t     --toserver            Sync file to server
        -w 	   --www				 Backup this directory "/var/www" default
EOF
}

if ! options=$(getopt -o i:mthv -l mysql,toserver,help,var: -n "backup.sh" -- "$@")
then
    exit 1
fi

set -- $options
while [ $# -gt 0 ] 
do
  case "$1" in
      -i) IGNORE="$IGNORE$2" ;;
      -m|--mysql) mysqlDump ;;
      -t|--toserver) rsyncTO ;;
      -h|--help) usage exit ;;
	  -w|--www) varDump ;;
      --) shift; break;;
      -*) echo "${RED}$0: error - unrecognized option $1${NC}" 1>&2; exit 1;;
      *) usage break exit 1;;
  esac
  shift
done
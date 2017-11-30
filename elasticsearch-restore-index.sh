#!/bin/bash
#
# elasticsearch-restore-index.sh
#
# Retrieve a specified logstash index via SCP and restore with an accompanying
# restore script.
#   http://logstash.net
#   http://www.elasticsearch.org
#   https://github.com/s3tools/s3cmd | http://s3tools.org/s3cmd
#
#   Inspiration:
#     http://tech.superhappykittymeow.com/?p=296
#
# Must run on an elasticsearch node with data, the restore script restarts
# elasticsearch.

usage()
{
cat << EOF

elasticsearch-restore-index.sh


USAGE: ./elasticsearch-restore-index.sh -b USER@SERVER:/PATH/TO/TARGET/ [OPTIONS]

OPTIONS:
  -h    Show this message
  -b    SCP path for backups (Required)
  -i    Elasticsearch index directory (Required)
  -d    Date to retrieve (Required, format: YYYY.mm.dd)
  -t    Temporary directory for download and extract (default: /tmp)
  -e    Elasticsearch URL (default: http://localhost:9200)
  -n    How nice tar must be (default: 19)

EXAMPLES:

  ./elasticsearch-restore-index.sh -b "user@server:/path/to/target/" -i /mnt/es/data/nodes/0/indices \
  -d "2013.05.01"

    Get the backup and restore script for the 2013.05.01 index from this 
    server and restore the index to the provided elasticsearch index directory.

EOF
}

if [ "$USER" != 'root' ] && [ "$LOGNAME" != 'root' ]; then
  # I don't want to troubleshoot the permissions of others
  echo "This script must be run as root."
  exit 1
fi

# Defaults
ELASTICSEARCH="http://localhost:9200"
NICE=19
TMP_DIR="/tmp"

while getopts ":b:i:t:d:e:n:h" flag
do
  case "$flag" in
    h)
      usage
      exit 0
      ;;
    b)
      SCP_BASE=$OPTARG
      ;;
    i)
      INDEX_DIR=$OPTARG
      ;;
    t)
      TMP_DIR=$OPTARG
      ;;
    d)
      DATE=$OPTARG
      ;;
    e)
      ELASTICSEARCH=$OPTARG
      ;;
    n)
      if [[ $OPTARG =~ $RE_D ]]; then
        NICE=$OPTARG
      fi
      # If nice is not an integer, just use default
      ;;
    ?)
      usage
      exit 1
      ;;
  esac
done

# We need an SCP base path
if [ -z "$SCP_BASE" ]; then
  ERROR="${ERROR}Please provide an scp user, server, and path with -b.\n"
fi

# We need an elasticsearch index directory
if [ -z "INDEX_DIR" ]; then
  ERROR="${ERROR}Please provide an Elasticsearch index directory with -i.\n"
fi

# We need a date to restore
if [ -z "$DATE" ]; then
  ERROR="${ERROR}Please provide a date for restoration with -d.\n"
fi

# If we have errors, show the errors with usage data and exit.
if [ -n "$ERROR" ]; then
  echo -e $ERROR
  usage
  exit 1
fi

# Default logstash index naming is hardcoded, as are YYYY-mm container directories.
INDEX="logstash-$DATE"
YEARMONTH=${DATE//\./-}
YEARMONTH=${YEARMONTH:0:7}
SCP_TARGET="$SCP_BASE/$YEARMONTH"

# Get archive and execute the restore script. TODO check file existence first
scp $SCP_TARGET/$INDEX.tgz $TMP_DIR/$INDEX.tgz
scp $SCP_TARGET/$INDEX-restore.sh $TMP_DIR/$INDEX-restore.sh

if [ -f $TMP_DIR/$INDEX-restore.sh ]; then
  chmod 750 $TMP_DIR/$INDEX-restore.sh
  $TMP_DIR/$INDEX-restore.sh

  # cleanup tmp files
  rm $TMP_DIR/$INDEX.tgz
  rm $TMP_DIR/$INDEX-restore.sh
else
  echo "Unable to find restore script, does that backup exist?"
  exit 1
fi

exit 0

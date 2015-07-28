#!/bin/bash


while [[ $# > 1 ]]
do
key="$1"

case $key in
    -s|--source-pool)
    SOURCEPOOL="$2"
    shift # past argument
    ;;
    -d|--dest-pool)
    DESTPOOL="$2"
    shift # past argument
    ;;
    -e|--dEst-host)
    DESTHOST="$2"
    shift # past argument
    ;;
    -m|--mode)
    MODE="$2"
    shift # past argument
    ;;
    -b|--backup)
    MODE="backup"
    shift # past argument
    ;;
    -r|--restore)
    MODE="restore"
    shift # past argument
    ;;
    -c|--chosen-date)
    CHOSEN_DATE="$2"
    shift # past argument
    ;;
    -h|--help)
    MODE="help"
    shift # past argument
    ;;
    --default)
    SOURCEPOOL="rbd"
    DESTPOOL="archive"
    DESTHOST="vagrant@192.168.200.5"
    ;;
    *)
            # unknown option
    ;;
esac
shift
done


if [ "$MODE" == "backup" ]; then
  #what is today's date?

  TODAY=`date +"%Y-%m-%d"`
  YESTERDAY=`date +"%Y-%m-%d" --date="1 days ago"`

  #list all images in the pool

  IMAGES=`sudo rbd ls $SOURCEPOOL`

  for LOCAL_IMAGE in $IMAGES; do

          #check whether remote host/pool has image

          if [[ -z $(ssh $DESTHOST sudo rbd ls $DESTPOOL | grep $LOCAL_IMAGE) ]]; then
                  echo "info: image does not exist in remote pool. creating new image"

                  #todo: check succesful creation

                  `ssh $DESTHOST sudo rbd create $DESTPOOL/$LOCAL_IMAGE -s 1`
          fi

          #create today's snapshot

          if [[ -z $(sudo rbd snap ls $SOURCEPOOL/$LOCAL_IMAGE | grep $TODAY) ]]; then
                  echo "info: creating snapshot $SOURCEPOOL/$LOCAL_IMAGE@$TODAY"
                  `sudo rbd snap create $SOURCEPOOL/$LOCAL_IMAGE@$TODAY`
          else
                  echo "warning: source image $SOURCEPOOL/$LOCAL_IMAGE@$TODAY already exists"
          fi

          # check whether to do a init or a full

          if [[ -z $(ssh $DESTHOST sudo rbd snap ls $DESTPOOL/$LOCAL_IMAGE) ]]; then
                  echo "info: no snapshots found for $DESTPOOL/$LOCAL_IMAGE doing init"
                  `sudo rbd export-diff $SOURCEPOOL/$LOCAL_IMAGE@$TODAY - | ssh $DESTHOST sudo rbd import-diff - $DESTPOOL/$LOCAL_IMAGE`
          else
                  echo "info: found previous snapshots for $DESTPOOL/$LOCAL_IMAGE doing diff"

                  #check yesterday's snapshot exists at remote pool

                  if [[ -z $(ssh $DESTHOST sudo rbd snap ls $DESTPOOL/$LOCAL_IMAGE | grep $YESTERDAY) ]]; then
                                  echo "error: --from-snap $LOCAL_IMAGE@$YESTERDAY does not exist on remote pool"
                                  exit 1
                  fi
                  #check todays's snapshot already exists at remote pool

                  if [[ -z $(ssh $DESTHOST sudo rbd snap ls $DESTPOOL/$LOCAL_IMAGE | grep $TODAY) ]]; then
                                  `sudo rbd export-diff --from-snap $YESTERDAY $SOURCEPOOL/$LOCAL_IMAGE@$TODAY - | ssh $DESTHOST sudo rbd import-diff - $DESTPOOL/$LOCAL_IMAGE`

                                  #comparing changed extents between source and destination

                                  SOURCE_HASH=`sudo rbd diff --from-snap $YESTERDAY $SOURCEPOOL/$LOCAL_IMAGE@$TODAY --format json | md5sum | cut -d ' ' -f 1`
                                  DEST_HASH=`ssh $DESTHOST sudo rbd diff --from-snap $YESTERDAY $DESTPOOL/$LOCAL_IMAGE@$TODAY --format json | md5sum | cut -d ' ' -f 1`

                                  if [ $SOURCE_HASH == $DEST_HASH ]; then
                                                  echo "info: changed extents hash check ok"
                                  else
                                                  echo "error: changed extents hash on source and destination don't match: $SOURCE_HASH not equals $DEST_HASH"
                                  fi
                  else
                                  echo "error: snapshot $DESTPOOL/$LOCAL_IMAGE@$TODAY already exists, skipping"
                                  exit 1
                  fi
          fi

  done
elif [ "$MODE" == "restore" ]; then

  IMAGES=`ssh $DESTHOST sudo rbd ls $DESTPOOL`


  for LOCAL_IMAGE in $IMAGES; do
    `sudo rbd create $SOURCEPOOL/$LOCAL_IMAGE`
    LATEST=`ssh $DESTHOST sudo rbd snap ls $DESTPOOL/LOCAL_IMAGE | tail -n 1 - | awk '{print $2}'`
    if [[ -z "$CHOSEN_DATE" ]]; then
    `ssh $DESTHOST sudo rbd export-diff $DESTPOOL/$LOCAL_IMAGE@$CHOSEN_DATE - | sudo rbd import-diff - $SOURCEPOOL/$LOCAL_IMAGE`
    else
    `ssh $DESTHOST sudo rbd export-diff $DESTPOOL/$LOCAL_IMAGE@$LATEST - | sudo rbd import-diff - $SOURCEPOOL/$LOCAL_IMAGE`
    fi
  done

elif [ "$MODE" == "purge" ]; then

  IMAGES=`ssh $DESTHOST sudo rbd ls $DESTPOOL`

  for LOCAL_IMAGE in $IMAGES; do
    SNAPS=`ssh $DESTHOST sudo rbd snap ls $LOCAL_IMAGE | head -n 7 -`
    for snap in $SNAPS; do

      `ssh $DESTHOST sudo rbd snap rm $LOCAL_IMAGE@$snap`

    done

  done

elif [ "$MODE" == "help" ]; then

  echo "snapinc is a cli client for backup/restore/purge of ceph rbd images from local machines to remote machines and vice-versa."
  echo "Syntax: "
  echo " "
  echo "snapinc <options>"
  echo " "
  echo "For backup (local to remote),"
  echo "snapinc -b -s [SOURCEPOOL] -d [DESTPOOL] -e [DESTHOST]"
  echo "or"
  echo "snapic -m backup -s [SOURCEPOOL] -d [DESTPOOL] -e [DESTHOST]"
  echo " "
  echo "For restore (remote to local),"
  echo "snapinc -r -s [SOURCEPOOL] -d [DESTPOOL] -e [DESTHOST] [-c [CHOSEN_DATE](optional)]"
  echo "or"
  echo "snapic -m restore -s [SOURCEPOOL] -d [DESTPOOL] -e [DESTHOST] [-c [CHOSEN_DATE] (optional)]"
  echo " "
  echo "For purge (delete remote),"
  echo "snapinc -p -s [SOURCEPOOL] -d [DESTPOOL] -e [DESTHOST]"
  echo "or"
  echo "snapic -m purge -s [SOURCEPOOL] -d [DESTPOOL] -e [DESTHOST] [-c [CHOSEN_DATE] (optional)]"
  echo " "
fi
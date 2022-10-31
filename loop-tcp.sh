#!/bin/bash

#Defaults
host="None"
filter="None"
pattern="None"
runCmd="None"  # Default <cmd>
fSize=200 # size of each capture files
minSize=`expr $fSize \* 2`
size=1000 # Default size to capture
maxSize=10000 # Maximum size. Limit to --size <size>
minFillTime=300 # Warning message if <size> can not hold captures for minFillTime
MonitorInterval=10 # interval to run <cmd> and to check the pattern
snaplen=0 # Length of each packet to be captured. 0 means default which is 256KB. 

n=`expr $fSize - 1`
m=`expr $maxSize + $n`
nMax=`expr $m / $fSize`
failed=0

getTs()
{
	t=`echo "$2" | cut -c1-15`
	t=`date -d "$t" +"%s" 2>/dev/null`
	[[ -z "$t" ]] && return 0
	echo $t
}

monitor()
{
	echot "Starting the monitor"
	lastRunTp=0

	if [ -z "$pattern" ]
	then
	  ss=".*"
	else
	    ss=$pattern
	fi
        p=`eval $runCmd 2>/tmp/$0_status.err |grep -a -E "$ss" | tail -1`
        if grep ": command not found" /tmp/$0_status.err >/dev/null 2>&1
	then
		echot "Command $runCmd FAILED! You need to run it with proper command for meaningful results in the capture" 
		echot $(cat /tmp/$0_status.err)
		failed=1
		exit 2
	fi
        HASH=`echo "$p"|md5sum | cut -f1 -d' '`

	# Exit if no pattern provided. Exit after running the command
	[ -z "$pattern" ] && echot "Command '$runCmd' completed. Exiting" && exit 0

	while true
	do
	    sleep $MonitorInterval
            p=`ps -p $PID |grep -v PID|grep -v grep`
            if [ -z "$p" ]
            then
		    echot "tcpdump is no longer running. Exiting"
		    exit 9
            fi
            p=`eval $runCmd | grep -a -E "$ss" |tail -1`
            h=`echo "$p"|md5sum | cut -f1 -d' '`
	    if [ -n "$p" -a "$h" != "$HASH" ]
	    then
		    echot "pattern found. Exiting"
		    exit 0
	    fi
	    totalSize=0
	    c=1
	    unset oldestPTime

	    listing="$(ls -trl --time-style=+%s ${dir}/${file}* 2>/dev/null | grep ^-)"
	    while read line
            do
		    s=`echo $line | awk '{print $5}'` # size of file
		    f=`echo $line | awk '{print $7}'` # file name
		    totalSize=`expr $totalSize + $s` # calcultate the total size of capture files in the directory
		    # get the time stamp on first packet of the oldest file
		    [ -z "$oldestPTime" ] && oldestPTime=`tcpdump -r $f -n -c 1 -tt 2>/dev/null| awk '{print $1}' | cut -f1 -d.`
		    c=`expr $c + 1`
            done <<< "$listing"

	    # check how much data is being captured within minFillTime
	    t=`date +%s` # current time
	    totalSize=`expr $totalSize / 1000000`
	    # Define a threshold for the check. % of total size getting filled quickly is a concern
	    threshold=$( echo "$size * 0.8" | bc |cut -f1 -d. )
	    [[ "$totalSize" -le "$threshold" ]]  && continue
	    if [ -n "$t" -a -n "$oldestPTime" -a "$t" -gt "$oldestPTime" ]
	    then
		    collectionTime=`expr $t - $oldestPTime`
		    tp=`expr $totalSize / $collectionTime` #tp is fill rate
		    [ "$collectionTime" -lt "$minFillTime" -a "$tp" -gt "$lastRunTp" ] && echot "Files rotating too fast - ${totalSize}MB in ${minFillTime}s (${tp}MB/s), increase --size, filter capture with --filter or use --snaplen"
	            lastRunTp=$tp
	    fi
        done
}

cleanup()
{
    # kill tcpdump gracefully and exit
    p=`ps -p $PID |grep -v PID|grep -v grep`
    if [ -n "$p" ]
    then
        kill $PID
	echot "Killed pid $PID process='$p'"
    fi
    if [ "$failed" != "1" ] 
    then
        echot "Captured Files:"
        echo "$(ls -ltr ${dir}/${file}*)"
        echo
        echot "Zip files using 'tar cvzf ${dir}/${file}.tgz ${dir}/${file}*'"
        echot "Capture finished"
    fi
}

startTcpDump()
{
	# Start tcpdump continously rotating files as per given parameters
	file=`basename $0`
	file=`echo $file | cut -f1 -d.`
	ttStamp=`date +%h-%d-%H_%M`
	file="${file}_$ttStamp"
	param="-i $interface -w $dir/$file -W $nFiles -C $fSize -Z root -s $snaplen $filter"
	# Start TCP in background
	tcpdump $param &
	PID=$!
	[[ -z "$PID" ]] && echot "tcpdump did not start. Exiting" && return 1
	sleep 1
	echot "tcpdump started with pid $PID"
	return 0
}

usage()
{
	echo
	echo "$0 starts the capture, keeping <size> amount of capture in a rotating fashion"
	echo "$0 runs the <cmd> continuously and look for <pattern> in the <cmd> output"
	echo "Once pattern is found, the capture is stopped and exits"
	echo "if no pattern is specified, <cmd> is run just once, stops the capture and exits."
	echo "This will handy to time box a command"
	echo
	echo "General paractice is to run loop-tcp.sh using nohup and keep it in background."
	echo "It will run until a <pattern> is discovered in the output of <cmd>"
	echo
	echo "Mandatory parameters are interface --interface <if> --dir <dir>"
	echo
	echo "Usage:"
	echo "$0 --interface <if> --dir <dir>"
	echo "        [--pattern <pattern>] [--size <totalSizeinMB>]"
        echo "        [--host <IP to filter>] [--filter <filter expression>]"
	echo "        [--runCmd <cmd>] [--snaplen <snapSize>]"
	echo
	echo "<if>                - Interface to be captured"
	echo
	echo "<dir>               - Directory to put the capture files"
	echo
	echo "<totalSizeinMB>     - Limit the total captures to <size>MB"
	echo "                      Size of each capture file is ${fSize}MB"
	echo "                      Default size is ${size}MB"
	echo "                      Minimum size is ${minSize}MB"
	echo "                      limit is ${maxSize}MB"
	echo
	echo "<pattern>           - A pattern in <cmd> output to stop tcpdump. When the pattern appears, the tcpdump will stop"
	echo "                      This is grep's Extended regular expression"
	echo "                      Eg: --pattern 'nfs: server .+ not responding' to stop the network capture when this pattern appears in /var/log/messages"
	echo "                      Not specifying a pattern will stop the tcpdump on first <cmd> execution regardless of output produced"
	echo "                      Eg: --runCmd 'mount 10.32.1.200:/fss-1/TEST /mnt' will capture packets during mount command"
	echo
	echo "<IP to filter>      - Filter traffic to and from this IP"
	echo
	echo "<filter expression> - A filter to be passed as tcpdump filter"
	echo "                      Eg: --filter 'port 2049'"
	echo
	echo "<cmd>               - A command to run to check if an event has happened. See <pattern>"
	echo "                      Eg: --runCmd 'cat /var/log/syslog'"
	echo "                      Default is 'cat /var/log/messages'"
	echo
	echo "<snapSize>          - Size of each packet to capture"
	echo "                      Default is full packet"
	echo
	exit 0
}

echot()
{
    ttStamp=`date +%h-%d-%H:%M:%S`
    h=$hostname
    /bin/echo -n "$ttStamp  $h "
    /bin/echo "$@"
    return 0
}

parseArgs()
{

    while [[ $# -gt 0 ]]; do
      key="$1"

      case $key in
        --size)
          size="$2"
          shift; shift
          ;;
        --help)
	  usage
          ;;
        --interface)
          interface=$2
          shift;shift
          ;;
        --host)
          host=$2
          shift;shift
          ;;
        --filter)
          filter="$2"
          shift;shift
          ;;
        --pattern)
          pattern="$2"
          shift;shift
          ;;
        --dir)
          dir="$2"
          shift;shift
          ;;
        --snaplen)
          snaplen="$2"
          shift;shift
          ;;
        --runCmd)
          runCmd="$2"
          shift;shift
          ;;
        *) # unknown options
          unknown+=("$1 ")
          shift
          ;;
      esac
    done

    # Check some sanity in to provided arguments
    [ -z "$interface" ] && echo "An interface must be specified with --interface option" && usage
    [ -z "$dir" ] && echo "A directory to place the capture files to be specified with --dir option"
    [ -z "$size" ] && echo "A size in MB must be specified with --size. This is the max size of captures that will be collected" && usage
    [ -z "$host" ] && echo "An IP address should be specified with --host to filter network capture on this IP" && usage
    [ -z "$filter" ] && echo "A filter must be specified with --filter to filter packet capture" && usage
    [ -z "$pattern" ] && echo "A pattern must be specified with --pattern" && usage
    [ -z "$runCmd" ] && echo "A pattern command to be specified with --runCmd. Default is 'cat'" && usage
    [ -z "$snaplen" ] && echo "A snap size must be specified with --snaplen. Default is capture everything" && usage
    [ -n "$unknown" ]  && echo "Unknown options $unknown" && usage
    [ "$pattern" = "None" -a "$runCmd" = "None" ] && echo "--runCmd is required with no pattern specified" && usage
} 

parseArgs "$@"

U=`id -u`
[[ "$U" -ne "0" ]] && echo "$0 should be run as root" && exit 5

# Make sure the capture size is not too big
n=`expr $fSize - 1`
m=`expr $size + $n`
nFiles=`expr $m / $fSize`
[[ "$nFiles" -lt "2" ]] && nFiles=2
size=`expr $nFiles \* $fSize`
[[ "$nFiles" -gt "$nMax" ]] && echo "Files=$nFiles, totalAllowed=${nMax}. Reduce the size (--size)" && exit 2

# Make sure the directory exist, accessible and is on a local filesystem
[ ! -d "$dir" ] && echo "Directory $dir does not exist" && exit 6
free=`df -l -m $dir | grep -v "^Filesystem " | awk '{print $4}'`
fs=`df -l -m $dir | grep -v "^Filesystem " | awk '{print $6}'`
[[ -z "$free" ]] && echo "Directory $dir should be a local FS" && exit 6

# Make sure we have atleast twise the required space
m=`expr $size \* 2`
[ "$free" -lt "$m" ] && echo "$dir in $fs has only ${free}MB, need ${m}MB" && exit 6

p=`ps -eaf | grep tcpdump |grep -v grep`
[[ -n "$p" ]] && echo "A tcpdump is already running. Exiting" && exit 7

[ "$host" = "None" ] && host=""
[ "$filter" = "None" ] && filter=""
[ "$pattern" = "None" ] && pattern=""
[ "$runCmd" = "None" ] && runCmd="cat /var/log/messages"
[ -n "$host" ] && filter="$filter host $host"

file=`basename $0`
file=`echo $file | cut -f1 -d.`
ttStamp=`date +%h-%d-%H_%M`
file="${file}_$ttStamp"

echot "Starting network capture in dir=$dir, file name pattern=$file"
echot "=$nFiles, totalSize=${size}MB, each FileSize=${fSize}MB"
echot "FS $fs has ${free}MB free. proceeding..."
[ -n "$filter" ] && echot "Capturing using filter='$filter'"
echot "runCmd='$runCmd'"
echot "pattern='$pattern'"


startTcpDump || exit 8
trap cleanup EXIT
monitor

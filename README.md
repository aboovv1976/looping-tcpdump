# looping-tcpdump

$ loop-tcp.sh --help

loop-tcp.sh starts the capture, keeping <size> amount of capture in a rotating fashion
loop-tcp.sh runs the <cmd> continuously and look for <pattern> in the <cmd> output
Once pattern is found, the capture is stopped and exits
if pattern specified is 'None', <cmd> is run just once and stops the capture and exits. This will handy to time box a command

General paractice is to run loop-tcp.sh using nohup and keep it in background. It will run until a pattern is discovered.
Mandatory parameters are interface --interface <if> --dir <dir>

loop-tcp.sh --interface <if> --dir <dir> [--pattern <pattern>] [--size <totalSizeinMB>] [--host <IP to filter>] [--filter <filter expression>] [--runCmd <cmd>] [--snaplen <snapSize>]

<if>                - Interface to be captured

<dir>               - Directory to put the capture files

<size>              - Limit the total captures to <size>MB
                      Size of each capture file is 200MB
                      Default size is 5000MB
                      Minimum size is 400MB
                      limit is 10000MB

<pattern>           - A pattern in <cmd> output to stop tcpdump. When the pattern appears, the tcpdump will stop
                      This is grep's Extended regular expression
                      Eg: --pattern 'nfs: server .+ not responding' to stop the network capture when this pattern appears in /var/log/messages
                      Not specifying a pattern will stop the tcpdump on first <cmd> execution regardless of output produced
                      Eg: --runCmd 'mount 10.32.1.200:/fss-1/TEST /mnt' will capture packets during mount command

<IP to filter>      - Filter traffic to and from this IP

<filter expression> - A filter to be passed as tcpdump filter
                      Eg: --filter 'port 2049'

<cmd>               - A filter to be passed as tcpdump filter
                      Eg: --runCmd 'cat /var/log/syslog'
                      Default is 'cat /var/log/messages'

<totalSize>         - Maximum size of the capture
                      Default is 1000 (1GB)

<snapSize>          - Size of each packet to capture
                      Default is full packet

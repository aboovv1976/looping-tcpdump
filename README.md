# looping-tcpdump

$ loop-tcp.sh --help

loop-tcp.sh starts the capture, keeping <size> amount of capture in a rotating fashion
loop-tcp.sh runs the <cmd> continuously and look for <pattern> in the <cmd> output
Once pattern is found, the capture is stopped and exits
if pattern specified is 'None', <cmd> is run just once and stops the capture and exits. This will handy to time box a command

Mandatory parameters are interface --interface <if> --dir <dir>

./loop-tcp.sh --interface <if> --dir <dir> --pattern <pattern> [--size <totalSizeinMB>] [--host <IP to filter>] [--filter <filter expression>] [--runCmd <cmd>] [--snaplen <snapSize>]

<if>                - Interface to be captured

<dir>               - Directory to put the capture files

<size>              - Limit the total captures to <size>MB
                      Default size is 1000MB
                      Minimum size is 400MB

<pattern>           - A pattern in <cmd> output to stop tcpdump. When the pattern appears, the tcpdump will stop
                      This is grep's Extended regular expression
                      '--pattern None' will stop the tcpdump on first <cmd> execution regardless of output produced
                      Eg: --pattern 'nfs: server .+ not responding'

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

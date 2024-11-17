# looping-tcpdump

```
$ ./loop-tcp.sh --help

./loop-tcp.sh starts the capture, keeping <size> amount of capture in a rotating fashion
It runs the <cmd> continuously and look for <pattern> in the <cmd> output
Once pattern is found, the capture is stopped and exits after <postFillSeconds> seconds

if no pattern is specified, <cmd> is run just once, stops the capture and exits after <postFillSeconds> seconds.
This will handy to time box a command

General paractice is to run ./loop-tcp.sh using nohup and keep it in background.

Mandatory parameters are interface --interface <if> --dir <dir>

Usage:
./loop-tcp.sh --interface <if> --dir <dir>
        [--pattern <pattern>] [--size <totalSizeinMB>]
        [--host <ipToFilter>] [--filter <filterExpression>]
        [--runCmd <cmd>] [--snaplen <snapSize>] [--postfill <postFillSeconds>]

<if>                - Interface to be captured

<dir>               - Directory to put the capture files

<totalSizeinMB>     - Limit the total captures to <size>MB
                      Size of each capture file is 200MB
                      Default size is 1000MB
                      Minimum size is 400MB
                      limit is 10000MB

<pattern>           - A pattern in <cmd> output to stop tcpdump. When the pattern appears, the tcpdump will stop
                      This is grep's Extended regular expression
                      Eg: --pattern 'nfs: server .+ not responding' to stop the network capture when this pattern appears in /var/log/messages
                      Not specifying a pattern will stop the tcpdump on first <cmd> execution regardless of output produced
                      Eg: --runCmd 'mount 10.32.1.200:/fss-1/TEST /mnt' will capture packets during mount command

<ipToFilter>        - Filter traffic to and from this IP

<filterExpression>  - A filter to be passed as tcpdump filter
                      Eg: --filter 'port 2049'

<cmd>               - A command to run to check if an event has happened. See <pattern>
                      Eg: --runCmd 'cat /var/log/syslog'
                      Default is 'cat /var/log/messages'

<snapSize>          - Size of each packet to capture
                      Default is full packet

<postFillSeconds>   - Fill the tcpdump for specified seconds before stopping tcpdump. Default is 0
```

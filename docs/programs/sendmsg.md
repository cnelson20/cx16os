[Back](./)

## sendmsg

#### send messages to other processes through the 8 general hooks

### Usage
`
sendmsg [-h 0-7] [-c byte] ... [-s string] ...
`
Options:
- `-h`: set the general hook number to send a message to
- `-c byte`: add 1 byte of data `byte` to the message. Can either be a decimal number or hex signified by a preceding $ or 0x.
- `-s string`: add the characters in `string` to the message.
Both `-c` and `-s` can be repeatedly used to craft a message

More information on cx16os's hook system can be found [here](/docs/system_hooks.md)

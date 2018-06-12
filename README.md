# Socket 
Interface to network communication.
Sockets will auto yield to other coroutines while waiting on a request.
All blocking operations use the timeout settings of the socket.
Reads are appended to the socket's read buffer which can 
be accessed using the readBuffer method.

Example:

```Io
socket := Socket clone setHost("www.google.com") setPort(80) connect
if(socket error) then( write(socket error, "\n"); exit)

socket write("GET /\n\n")

while(socket read, Nop)
if(socket error) then(write(socket error, "\n"); exit)

write("read ", socket readBuffer length, " bytes\n")

```

# Installation

`libevent` should be installed and foundable in your system. Then:

```
eerie install https://github.com/IoLanguage/Socket.git
```

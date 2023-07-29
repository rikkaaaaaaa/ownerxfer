# ownerxfer

a simple script to allow easily transferring ownership of entities between
players

automatically transfers all constrained entities too

originally made for my own server, but i figured it might be useful to someone
else

should work with any CPPI-compatible prop protection (almost all of them)

also supports an admin override via ULX/ULib permissions out of box (falls back
to player:IsSuperAdmin() if ULX isnt available), and you can detour
ownerxfer.canOverride(ply) to support your specific setup

let me know if you have any issues (or just unpack it and edit it yourself, that
works too; the license is 0bsd!)
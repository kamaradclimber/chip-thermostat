#!/bin/bash

set -ex

curl -s -f https://familleseux.net/chip.sh -O
chmod +x chip.sh

cat chip.sh

./chip.sh

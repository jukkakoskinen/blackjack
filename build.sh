#!/bin/sh
set -e

mkdir -p ./bin
odin build ./src -out:./bin/blackjack -o:speed

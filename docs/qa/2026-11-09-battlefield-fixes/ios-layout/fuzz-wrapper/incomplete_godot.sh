#!/bin/sh
case "$*" in
 *--import*) exit 0;;
 *) echo "FUZZR incomplete negative harness probe"; exit 0;;
esac

#!/bin/sh

umask 022
/opt/r-lib/bin/pango-querymodules > ${1}.cache

#!/bin/sh

CFGDIR=~/.config/sublime-text-3
if [ `uname` = "Darwin" ]; then
	CFGDIR=~/Library/Application\ Support/Sublime\ Text\ 3
fi

cp *.sublime-snippet ${CFGDIR}/Packages/User/


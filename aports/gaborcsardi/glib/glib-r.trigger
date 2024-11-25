#!/bin/sh

for i in "$@"; do
	if ! [ -e "$i" ]; then
		continue
	fi
	case "$i" in
	*/modules|*gtk-4.0)
		/opt/r-lib/bin/gio-querymodules "$i"
		;;
	*/schemas)
		/opt/r-lib/bin/glib-compile-schemas "$i"
		;;
	esac
done


#!/bin/sh

srcdir=`dirname $0`

PKG_NAME="libunity"

which gnome-autogen.sh || {
        echo "You need gnome-common from the GNOME Git repository"
        exit 1
}

USE_GNOME2_MACROS=1 \
. gnome-autogen.sh

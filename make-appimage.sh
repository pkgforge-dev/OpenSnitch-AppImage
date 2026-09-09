#!/bin/sh

set -eu

ARCH=$(uname -m)
export ARCH
export OUTPATH=./dist
export ADD_HOOKS="self-updater.hook"
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync"
export APPNAME=OpenSnitch
export ICON=/usr/share/icons/hicolor/scalable/apps/opensnitch-ui.svg
export DESKTOP=/usr/share/applications/opensnitch_ui.desktop
export DEPLOY_PYTHON=1
export ALWAYS_SOFTWARE=1
export STRACE_BINARY=opensnitch-ui

# Deploy dependencies
quick-sharun \
	/usr/bin/opensnitch*   \
	/usr/bin/setcap        \
	/usr/bin/getcap        \
	/usr/share/opensnitchd \
	/usr/lib/libcares.so*  \
	/usr/lib/libabsl_*.so*

# add markers in the config file that get replaced at runtime
# ebpf is kernel specific and not portable, use proc instead
sed -i \
	-e 's|/etc/opensnitchd|@CONFIGDIR@|g'                            \
	-e 's|/var/log/opensnitchd.log|@CONFIGDIR@/opensnitchd.log|'     \
	-e 's|"ProcMonitorMethod": *"ebpf"|"ProcMonitorMethod": "proc"|' \
	./AppDir/share/opensnitchd/default-config.json

# Turn AppDir into AppImage
quick-sharun --make-appimage

# Test the app for 12 seconds, if the test fails due to the app
# having issues running in the CI use --simple-test instead
quick-sharun --simple-test ./dist/*.AppImage

#!/bin/sh

set -eu

ARCH=$(uname -m)

echo "Installing package dependencies..."
echo "---------------------------------------------------------------"
pacman -Syu --noconfirm \
	go                  \
	libcap              \
	libmnl              \
	libnetfilter_queue  \
	libnfnetlink        \
	protobuf            \
	python              \
	python-build        \
	python-grpcio       \
	python-installer    \
	python-jaraco.text  \
	python-notify2      \
	python-packaging    \
	python-pyinotify    \
	python-pyqt6        \
	python-protobuf     \
	python-qt-material  \
	python-setuptools   \
	python-slugify      \
	python-wheel        \
	qt6-tools

echo "Installing debloated packages..."
echo "---------------------------------------------------------------"
get-debloated-pkgs --add-common --prefer-nano

# OpenSnitch pins old grpc/protobuf versions in go.mod, newer protoc
# plugins generate code that does not build against them
echo "Installing pinned protoc plugins..."
echo "---------------------------------------------------------------"
go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.26.0
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v1.1.0
PATH=$(go env GOPATH)/bin:$PATH
export PATH

# If the application needs to be manually built that has to be done down here
echo "Building opensnitch..."
echo "---------------------------------------------------------------"
git clone https://github.com/evilsocket/opensnitch.git ./opensnitch && (
	cd ./opensnitch
	# Build the latest stable tag
	TAG=$(git tag --list 'v*' --sort=-v:refname | grep -vi 'rc\|alpha\|beta' | head -n 1)
	git checkout "$TAG"
	VERSION="${TAG#v}"
	echo "$VERSION" > ~/version
)

# generate the Go protobuf files, the python ones are already committed
(
	cd ./opensnitch/proto
	protoc -I. ui.proto \
		--go_out=../daemon/ui/protocol/ --go-grpc_out=../daemon/ui/protocol/ \
		--go_opt=paths=source_relative --go-grpc_opt=paths=source_relative
)

# build the daemon
(
	cd ./opensnitch/daemon
	go build -o opensnitchd .
	cp opensnitchd /usr/bin/
)

# the gui lists the i18n dir at runtime, so the .qm files are mandatory
(
	cd ./opensnitch/ui/i18n
	./generate_i18n.sh
	for lang in ./locales/*/; do
		lang=${lang#./locales/}
		lang=${lang%/}
		mkdir -p ../opensnitch/i18n/"$lang"
		cp ./locales/"$lang"/opensnitch-"$lang".qm ../opensnitch/i18n/"$lang"
	done
)

# build and install the gui
(
	cd ./opensnitch/ui
	python -m build --wheel --no-isolation
	python -m installer --prefix=/usr ./dist/*.whl
)

# install the config files, these are copied to a writable location at runtime
mkdir -p /usr/share/opensnitchd/rules /usr/share/opensnitchd/tasks
cp -v ./opensnitch/daemon/data/default-config.json /usr/share/opensnitchd/
cp -v ./opensnitch/daemon/data/system-fw.json /usr/share/opensnitchd/
cp -v ./opensnitch/daemon/data/network_aliases.json /usr/share/opensnitchd/
cp -v ./opensnitch/daemon/data/rules/*.json /usr/share/opensnitchd/rules/
cp -v ./opensnitch/daemon/data/tasks/tasks.json /usr/share/opensnitchd/tasks/

# if you also have to make nightly releases check for DEVEL_RELEASE = 1
#
# if [ "${DEVEL_RELEASE-}" = 1 ]; then
# 	nightly build steps
# else
# 	regular build steps
# fi

# Top-level Makefile for workspaces
#
# AUTHORS
#
# The Veracruz Development Team.
#
# COPYRIGHT AND LICENSING
#
# See the `LICENSING.markdown` file in the Veracruz root directory for
# licensing and copyright information.

default:

include common.mk

.PHONY: all clean icecap icecap-clean linux linux-clean nitro nitro-clean \
	shared shared-clean

all: shared linux nitro icecap

clean: shared-clean linux-clean nitro-clean icecap-clean

linux: shared
	$(MAKE) -C linux-host
	$(MAKE) -C linux-runtime

nitro: shared
	$(MAKE) -C nitro-host
	$(MAKE) -C nitro-runtime

icecap: shared
	$(MAKE) -C icecap-runtime runtime-manager
	$(MAKE) -C icecap-host test-system

shared:
	$(MAKE) -C applications
	$(MAKE) -C host

linux-clean:
	$(MAKE) -C linux-host clean
	$(MAKE) -C linux-runtime clean

nitro-clean:
	$(MAKE) -C nitro-host clean
	$(MAKE) -C nitro-runtime clean

icecap-clean:
	$(MAKE) -C icecap-host clean
	$(MAKE) -C icecap-runtime clean

shared-clean:
	$(MAKE) -C applications clean
	$(MAKE) -C host clean

clean-cargo-lock:
	rm -f */Cargo.lock

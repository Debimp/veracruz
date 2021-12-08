# This makefile is used within the docker image generated by docker/Dockerfile
#
# AUTHORS
#
# The Veracruz Development Team.
#
# COPYRIGHT
#
# See the `LICENSE_MIT.markdown` file in the Veracruz root directory for licensing
# and copyright information.

.PHONY: all sdk setup-githooks nitro-veracruz-client-test clean clean-cargo-lock fmt linux linux-veracruz-server-test linux-veracruz-server-test-dry-run linux-test-collateral linux-veracruz-client-test linux-veracruz-test-dry-run linux-veracruz-test linux-cli

WARNING_COLOR := "\e[1;33m"
INFO_COLOR := "\e[1;32m"
RESET_COLOR := "\e[0m"
AARCH64_GCC ?= $(OPTEE_DIR)/toolchains/aarch64/bin/aarch64-linux-gnu-gcc
OPENSSL_INCLUDE_DIR ?= /usr/include/aarch64-linux-gnu
OPENSSL_LIB_DIR ?= /usr/lib/aarch64-linux-gnu
NITRO_RUST_FLAG ?= ""
LINUX_RUST_FLAG ?= ""
BIN_DIR ?= /usr/local/cargo/bin

all:
	@echo $(WARNING_COLOR)"Please explicitly choose a target."$(RESET_COLOR)

setup-githooks:
	rustup component add rustfmt
	git config core.hooksPath githooks

# Build all of the SDK and examples
sdk:
	$(MAKE) -C sdk

# Generate all test policy
linux-test-collateral:
	TEE=linux $(MAKE) -C test-collateral

nitro-veracruz-client-test: nitro nitro-test-collateral
	cd veracruz-client && cargo test --lib --features "mock" -- --test-threads=1

linux-veracruz-client-test: linux linux-test-collateral
	cd veracruz-client && cargo test --lib --features "mock linux" -- --test-threads=1

nitro-test-collateral:
	TEE=nitro $(MAKE) -C test-collateral

nitro: sdk
	rustup target add x86_64-unknown-linux-musl
	RUSTFLAGS=$(NITRO_RUST_FLAG) $(MAKE) -C runtime-manager nitro

nitro-cli:
	# enclave binaries needed for veracruz-server
	pwd
	RUSTFLAGS=$(NITRO_RUST_FLAG) $(MAKE) -C runtime-manager nitro
	# build CLIs in top-level crates
	cd proxy-attestation-server && RUSTFLAGS=$(NITRO_RUST_FLAG) cargo build --features nitro --features cli
	cd veracruz-server && RUSTFLAGS=$(NITRO_RUST_FLAG) cargo build --features nitro --features cli
	cd veracruz-client && RUSTFLAGS=$(NITRO_RUST_FLAG) cargo build --features nitro --features cli
	# build CLIs in the SDK/test-collateral
	$(MAKE) -C sdk/freestanding-execution-engine
	$(MAKE) -C sdk/wasm-checker
	$(MAKE) -C test-collateral/generate-policy

%-cli-install: %-cli
	# install to Cargo's bin directory
	cp -f proxy-attestation-server/target/debug/proxy-attestation-server $(BIN_DIR)/proxy-attestation-server
	cp -f veracruz-server/target/debug/veracruz-server $(BIN_DIR)/veracruz-server
	cp -f veracruz-client/target/debug/veracruz-client $(BIN_DIR)/veracruz-client
	# install CLIs in SDK/test-collateral
	cp -f sdk/freestanding-execution-engine/target/release/freestanding-execution-engine $(BIN_DIR)/freestanding-execution-engine
	cp -f sdk/wasm-checker/bin/wasm-checker $(BIN_DIR)/wasm-checker
	cp -f test-collateral/generate-policy/target/release/generate-policy $(BIN_DIR)/generate-policy
	# symlink concise names
	ln -sf $(BIN_DIR)/proxy-attestation-server      $(BIN_DIR)/vc-pas
	ln -sf $(BIN_DIR)/veracruz-server               $(BIN_DIR)/vc-server
	ln -sf $(BIN_DIR)/veracruz-client               $(BIN_DIR)/vc-client
	ln -sf $(BIN_DIR)/freestanding-execution-engine $(BIN_DIR)/vc-fee
	ln -sf $(BIN_DIR)/wasm-checker                  $(BIN_DIR)/vc-wc
	ln -sf $(BIN_DIR)/generate-policy               $(BIN_DIR)/vc-pgen
	# symlink backwards compatible names
	ln -sf $(BIN_DIR)/generate-policy               $(BIN_DIR)/pgen

# Using wildcard in the dependencies because if they are there, and newer, it
# should be rebuilt, but if they aren't there, they don't need to be built
# (they are optional)
veracruz-test/proxy-attestation-server.db: $(wildcard sgx-root-enclave/css.bin)
	cd veracruz-test && \
		bash ../test-collateral/populate-test-database.sh

# Using wildcard in the dependencies because if they are there, and newer, it
# should be rebuilt, but if they aren't there, they don't need to be built
# (they are optional)
veracruz-server-test/proxy-attestation-server.db: $(wildcard sgx-root-enclave/css.bin)
	cd veracruz-server-test && \
		bash ../test-collateral/populate-test-database.sh
linux: sdk
	pwd
	RUSTFLAGS=$(LINUX_RUST_FLAG) $(MAKE) -C runtime-manager linux
	RUSTFLAGS=$(LINUX_RUST_FLAG) $(MAKE) -C linux-root-enclave linux

linux-cli:
	# build CLIs in top-level crates
	cd proxy-attestation-server && RUSTFLAGS=$(LINUX_RUST_FLAG) cargo build --features linux --features cli
	cd veracruz-server && RUSTFLAGS=$(LINUX_RUST_FLAG) cargo build --features linux --features cli
	cd veracruz-client && RUSTFLAGS=$(LINUX_RUST_FLAG) cargo build --features linux --features cli
	# build CLIs in the SDK/test-collateral
	$(MAKE) -C sdk/freestanding-execution-engine
	$(MAKE) -C sdk/wasm-checker
	$(MAKE) -C test-collateral/generate-policy

nitro-veracruz-server-test: nitro nitro-test-collateral veracruz-server-test/proxy-attestation-server.db
	cd veracruz-server-test \
		&& RUSTFLAGS=$(NITRO_RUST_FLAG) cargo test --features nitro,debug -- --test-threads=1\
		&& RUSTFLAGS=$(NITRO_RUST_FLAG) cargo test test_debug --features nitro,debug -- --ignored --test-threads=1
	cd veracruz-server-test \
		&& ./nitro-terminate.sh

linux-veracruz-server-test-dry-run: linux linux-test-collateral
	cd veracruz-server-test \
		&& RUSTFLAGS=$(LINUX_RUST_FLAG) cargo test --features linux --no-run -- --nocapture

linux-veracruz-server-test: linux linux-test-collateral veracruz-server-test/proxy-attestation-server.db
	cd veracruz-server-test \
		&& RUSTFLAGS=$(LINUX_RUST_FLAG) cargo test --features linux -- --test-threads=1 --nocapture \
		&& RUSTFLAGS=$(LINUX_RUST_FLAG) cargo test test_debug --features linux  -- --ignored --test-threads=1

nitro-veracruz-server-test-dry-run: nitro nitro-test-collateral
	cd veracruz-server-test \
		&& RUSTFLAGS=$(NITRO_RUST_FLAG) cargo test --features sgx --no-run

nitro-veracruz-server-performance: nitro nitro-test-collateral veracruz-server-test/proxy-attestation-server.db
	cd veracruz-server-test \
		&& RUSTFLAGS=$(NITRO_RUST_FLAG) cargo test test_performance_ --features nitro -- --ignored
	cd veracruz-server-test \
		&& ./nitro-terminate.sh
	cd ./veracruz-server-test \
		&& ./nitro-ec2-terminate-root.sh

nitro-veracruz-test-dry-run: nitro nitro-test-collateral
	cd veracruz-test \
		&& RUSTFLAGS=$(SGX_RUST_FLAG) cargo test --features nitro --no-run

nitro-veracruz-test: nitro nitro-test-collateral veracruz-test/proxy-attestation-server.db
	cd veracruz-test \
		&& RUSTFLAGS=$(SGX_RUST_FLAG) cargo test --features nitro -- --test-threads=1
	cd veracruz-server-test \
		&& ./nitro-terminate.sh
	cd ./veracruz-server-test \
		&& ./nitro-ec2-terminate_root.sh

nitro-psa-attestation:
	cd psa-attestation && cargo build --features nitro

linux-veracruz-test-dry-run: linux-test-collateral
	cd veracruz-test \
		&& RUSTFLAGS=$(LINUX_RUST_FLAG) cargo test --features linux --no-run

linux-veracruz-test: linux-test-collateral linux veracruz-test/proxy-attestation-server.db
	cd veracruz-test \
		&& RUSTFLAGS=$(LINUX_RUST_FLAG) cargo test --features linux -- --test-threads=1

clean:
	# remove databases and binaries since these can easily fall out of date
	rm -rf bin
	rm -f proxy-attestation-server/proxy-attestation-server.db
	rm -f veracruz-server-test/proxy-attestation-server.db
	rm -f veracruz-test/proxy-attestation-server.db
	# clean code
	cd execution-engine && cargo clean
	cd io-utils && cargo clean
	cd linux-root-enclave && cargo clean
	cd platform-services && cargo clean
	cd policy-utils && cargo clean
	cd proxy-attestation-server && cargo clean
	cd psa-attestation && cargo clean
	$(MAKE) clean -C runtime-manager
	cd runtime-manager-bind && cargo clean
	$(MAKE) clean -C sdk
	cd session-manager && cargo clean
	$(MAKE) clean -C test-collateral
	cd transport-protocol && cargo clean
	cd veracruz-client && cargo clean
	$(MAKE) clean -C veracruz-mcu-client
	cd veracruz-server && cargo clean
	cd veracruz-server-test && cargo clean
	cd veracruz-test && cargo clean
	cd veracruz-utils && cargo clean

# clean-quick cleans everything but LLVM (in wasm-checker)
quick-clean:
	# remove databases and binaries since these can easily fall out of date
	rm -rf bin
	rm -f proxy-attestation-server/proxy-attestation-server.db
	rm -f veracruz-server-test/proxy-attestation-server.db
	rm -f veracruz-test/proxy-attestation-server.db
	# clean code
	cd execution-engine && cargo clean
	cd io-utils && cargo clean
	cd linux-root-enclave && cargo clean
	cd platform-services && cargo clean
	cd policy-utils && cargo clean
	cd proxy-attestation-server && cargo clean
	cd psa-attestation && cargo clean
	$(MAKE) quick-clean -C runtime-manager
	cd runtime-manager-bind && cargo clean
	$(MAKE) quick-clean -C sdk
	cd session-manager && cargo clean
	$(MAKE) quick-clean -C test-collateral
	cd transport-protocol && cargo clean
	cd veracruz-client && cargo clean
	$(MAKE) quick-clean -C veracruz-mcu-client
	cd veracruz-server && cargo clean
	cd veracruz-server-test && cargo clean	
	cd veracruz-test && cargo clean
	cd veracruz-utils && cargo clean

# NOTE: this target deletes ALL cargo.lock.
clean-cargo-lock:
	$(MAKE) -C sdk clean-cargo-lock
	$(MAKE) -C test-collateral clean-cargo-lock
	rm -f $(addsuffix /Cargo.lock,execution-engine io-utils linux-root-enclave platform-services policy-utils proxy-attestation-server psa-attestation runtime-manager runtime-manager-bind session-manager transport-protocol veracruz-client veracruz-server veracruz-server-test veracruz-test veracruz-utils)

# update dependencies, note does NOT change Cargo.toml, useful if
# patched/github dependencies have changed without version bump
update:
	cd execution-engine && cargo update
	cd io-utils && cargo update
	cd linux-root-enclave && cargo update
	cd platform-services && cargo update
	cd policy-utils && cargo update
	cd proxy-attestation-server && cargo update
	cd psa-attestation && cargo update
	$(MAKE) update -C runtime-manager
	cd runtime-manager-bind && cargo update
	$(MAKE) update -C sdk
	cd session-manager && cargo update
	$(MAKE) update -C test-collateral
	cd transport-protocol && cargo update
	cd veracruz-client && cargo update
	$(MAKE) update -C veracruz-mcu-client
	cd veracruz-server && cargo update
	cd veracruz-server-test && cargo update
	cd veracruz-test && cargo update
	cd veracruz-utils && cargo update

fmt:
	cd execution-engine && cargo fmt
	cd io-utils && cargo fmt
	cd linux-root-enclave && cargo fmt
	cd platform-services && cargo fmt
	cd policy-utils && cargo fmt
	cd proxy-attestation-server && cargo fmt
	cd psa-attestation && cargo fmt
	$(MAKE) fmt -C runtime-manager
	cd runtime-manager-bind && cargo fmt
	$(MAKE) fmt -C sdk
	cd session-manager && cargo fmt
	$(MAKE) fmt -C test-collateral
	cd transport-protocol && cargo fmt
	cd veracruz-client && cargo fmt
	$(MAKE) fmt -C veracruz-mcu-client
	cd veracruz-server && cargo fmt
	cd veracruz-server-test && cargo fmt
	cd veracruz-test && cargo fmt
	cd veracruz-utils && cargo fmt

# Helpers for building and running the composer docker images
# Set IMPORT_PATH to the path of the rpms to import or bind mount to ./rpms/
IMPORT_PATH ?= $(PWD)

GIT_ORG_URL=git+ssh://git@github.com/wiggum
REPOS=bdcs bdcs-api-rs composer-UI

default: all

repos: $(REPOS)

weld-f24: Dockerfile-weld-f24
	if [ ! -d ./build-weld-fedora/ ]; then \
		mkdir ./build-weld-fedora/; \
	fi; \
	cp Dockerfile-weld-f24 ./build-weld-fedora/Dockerfile
	sudo docker build -t weld/fedora:24 ./build-weld-fedora/

# given a repo in REPOS, clone it from GIT_ORG_URL
$(REPOS):%:
	git clone $(GIT_ORG_URL)/$@

# clone from local copies of repos
local-repos: GIT_ORG_URL=..
local-repos: clean repos

# Build the wiggum/* docker images. No rpms are imported and no images are run.
build: repos weld-f24
	sudo $(MAKE) -C bdcs importer
	sudo docker-compose build

# This uses local checkouts one directory above
build-local: local-repos build

# Import the RPMS from IMPORT_PATH and create the bdcs-mddb-volume
import: repos
	@if [ -h $(IMPORT_PATH)/rpms ]; then \
		echo "ERROR: $(IMPORT_PATH)/rpms/ cannot be a symlink"; \
		exit 1; \
	fi; \
	if [ ! -d $(IMPORT_PATH)/rpms ]; then \
		echo "ERROR: $(IMPORT_PATH)/rpms/ must exist"; \
		exit 1; \
	fi; \
	sudo WORKSPACE=$(IMPORT_PATH) $(MAKE) -C bdcs mddb

import-metadata:
	@if [ ! -f ./metadata.db ]; then \
		echo "ERROR: missing ./metadata.db file" \
		exit 1; \
	fi; \
	sudo docker volume create -d local --opt o=size=2GB --name bdcs-mddb-volume
	sudo docker create --name import-mddb -v bdcs-mddb-volume:/mddb/:z wiggum/bdcs-api
	sudo docker cp ./metadata.db import-mddb:/mddb/
	sudo docker rm import-mddb

run: repos
	sudo docker-compose up

run-background: repos
	sudo docker-compose up -d

all:
	@echo "Try 'make build', 'make import', or 'make run'."
	@echo "(make sure Docker is running first!)"

clean:
	rm -rf $(REPOS)


.PHONY: clean build import run build-local

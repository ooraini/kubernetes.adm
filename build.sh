#!/usr/bin/env bash
set -e
cd /home/omar/lab/ansible_collections/kubernetes/adm

export ANSIBLE_COLLECTIONS_PATH=/home/omar/lab/

# Create collection documentation into temporary directory
rm -rf temp-rst
mkdir -m 700 -p temp-rst
antsibull-docs collection --use-current --dest-dir temp-rst kubernetes.adm

# Build Sphinx site
sphinx-build -M html temp-rst/collections build -c . -W --keep-going


SPHINXOPTS    ?=
SPHINXBUILD   ?= sphinx-build
SOURCEDIR     = temp-rst/collections
BUILDDIR      = build
COLLECTION    = kubernetes.adm

# Put it first so that "make" without argument is like "make help".
help:
	@$(SPHINXBUILD) -M help "$(SOURCEDIR)" "$(BUILDDIR)" -c . $(SPHINXOPTS) $(O)
	@echo -e 'Additional targets: \x1B[97mbuild_modules\x1B[0m, \x1B[97mhtml_complete\x1B[0m'

build_modules:
	ansible-galaxy collection build --force .
	ansible-galaxy collection install --force kubernetes-adm-*.tar.gz
	rm -rf temp-rst
	mkdir -m 700 temp-rst
	antsibull-docs collection --use-current --dest-dir temp-rst $(COLLECTION)

html_complete: build_modules html
	#

open:
	xdg-open build/html/index.html

download_scripts:
	cd roles/prepare/files && curl -o kubectl_aliases https://raw.githubusercontent.com/ahmetb/kubectl-aliases/master/.kubectl_aliases
	cd roles/prepare/files && curl -O https://raw.githubusercontent.com/cykerway/complete-alias/master/complete_alias

github:
	@make html_complete
	@cp -a build/html/. ./docs

.PHONY: help Makefile

# Catch-all target: route all unknown targets to Sphinx using the new
# "make mode" option.  $(O) is meant as a shortcut for $(SPHINXOPTS).
%: Makefile
	@$(SPHINXBUILD) -M $@ "$(SOURCEDIR)" "$(BUILDDIR)" -c . $(SPHINXOPTS) $(O)

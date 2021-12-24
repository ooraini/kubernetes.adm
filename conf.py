# This file only contains a selection of the most common options. For a full list see the
# documentation:
# http://www.sphinx-doc.org/en/master/config

project = 'Ansible collections'
copyright = 'Ansible contributors'

title = 'Ansible Collections Documentation'
html_short_title = 'Ansible Collections Documentation'

extensions = ['sphinx.ext.autodoc', 'sphinx.ext.intersphinx', 'sphinx_antsibull_ext']

pygments_style = 'ansible'

highlight_language = 'YAML+Jinja'

html_static_path = ['_static']

html_theme = 'sphinx_rtd_theme'
html_show_sphinx = False

html_css_files = [
    'ansible.css',
]

display_version = False

html_use_smartypants = True
html_use_modindex = False
html_use_index = False
html_copy_source = False

default_role = 'any'

nitpicky = True


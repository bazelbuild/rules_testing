# Configuration file for the Sphinx documentation builder.

# -- Project information

project = 'rules_testing'
copyright = '2023, The Bazel Authors'
author = 'Bazel'

release = '0.1'
version = '0.1.0'

# -- General configuration

extensions = [
    'sphinx.ext.duration',
    'sphinx.ext.doctest',
    'sphinx.ext.autodoc',
    'sphinx.ext.autosummary',
    'sphinx.ext.intersphinx',
    'sphinx.ext.autosectionlabel',
    'myst_parser',
    'sphinx_rtd_theme', # Necessary to get jquery to make flyout work
]

intersphinx_mapping = {
}

intersphinx_disabled_domains = ['std']

# Prevent local refs from inadvertently linking elsewhere, per
# https://docs.readthedocs.io/en/stable/guides/intersphinx.html#using-intersphinx
intersphinx_disabled_reftypes = ["*"]

templates_path = ['_templates']

# -- Options for HTML output

html_theme = 'sphinx_rtd_theme'

html_theme_options = {
}

myst_enable_extensions = [
    "fieldlist",
    "attrs_block",
    "attrs_inline",
    "colon_fence",
    "deflist",
]

# These folders are copied to the documentation's HTML output
html_static_path = ['_static']

# These paths are either relative to html_static_path
# or fully qualified paths (eg. https://...)
html_css_files = [
    'css/custom.css',
]

# -- Options for EPUB output
epub_show_urls = 'footnote'


# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Check that the current README.rst is built from the template."""


from __future__ import print_function

import difflib
import json
import os


_SCRIPTS_DIR = os.path.dirname(__file__)
_ROOT_DIR = os.path.abspath(os.path.join(_SCRIPTS_DIR, '..'))
TEMPLATE_FILE = os.path.join(_ROOT_DIR, 'README.rst.template')
TEMPLATES_FILE = os.path.join(_ROOT_DIR, 'README.templates.json')
ACTUAL_FILE = os.path.join(_ROOT_DIR, 'README.rst')

PYPI_IMG = """
.. |pypi| image:: https://img.shields.io/pypi/v/bezier.svg
   :target: https://pypi.python.org/pypi/bezier
   :alt: PyPI Latest"""
VERSIONS_IMG = """
.. |versions| image:: https://img.shields.io/pypi/pyversions/bezier.svg
   :target: https://pypi.python.org/pypi/bezier
   :alt: Package Versions"""
ZENODO_IMG = """
.. |zenodo| image:: https://zenodo.org/badge/73047402.svg
   :target: https://zenodo.org/badge/latestdoi/73047402
   :alt: Zenodo DOI for ``bezier``"""
JOSS_IMG = """
.. |JOSS| image:: http://joss.theoj.org/papers/10.21105/joss.00267/status.svg
   :target: https://dx.doi.org/10.21105/joss.00267
   :alt: "Journal of Open Source Science" DOI for ``bezier``"""


def get_diff(value1, value2, name1, name2):
    """Get a diff between two strings.

    Args:
        value1 (str): First string to be compared.
        value2 (str): Second string to be compared.
        name1 (str): Name of the first string.
        name2 (str): Name of the second string.

    Returns:
        str: The full diff.
    """
    lines1 = [line + '\n' for line in value1.splitlines()]
    lines2 = [line + '\n' for line in value2.splitlines()]
    diff_lines = difflib.context_diff(
        lines1, lines2, fromfile=name1, tofile=name2)
    return ''.join(diff_lines)


def main():
    """Populate the template and compare values.

    Raises:
        ValueError: If the current README doesn't agree with the expected
            value computed from the template.
    """
    with open(TEMPLATE_FILE, 'r') as file_obj:
        template = file_obj.read()

    with open(TEMPLATES_FILE, 'r') as file_obj:
        templates_info = json.load(file_obj)

    rtd_version = 'latest'
    revision = 'master'
    img_prefix = templates_info['img_prefix'].format(revision=revision)
    extra_links = templates_info['extra_links'].format(
        rtd_version=rtd_version, revision=revision)
    docs_img = templates_info['docs_img'].format(rtd_version=rtd_version)
    expected = template.format(
        img_prefix=img_prefix,
        extra_links=extra_links,
        docs='|docs| ',
        docs_img=docs_img,
        pypi='\n\n|pypi| ',
        pypi_img=PYPI_IMG,
        versions='|versions|\n\n',
        versions_img=VERSIONS_IMG,
        rtd_version=rtd_version,
        coveralls_branch='master',
        revision=revision,
        zenodo='|zenodo|',
        zenodo_img=ZENODO_IMG,
        joss=' |JOSS|',
        joss_img=JOSS_IMG,
    )

    with open(ACTUAL_FILE, 'r') as file_obj:
        contents = file_obj.read()

    if contents != expected:
        err_msg = '\n' + get_diff(
            contents, expected, 'README.rst.actual', 'README.rst.expected')
        raise ValueError(err_msg)
    else:
        print('README contents are as expected.')


if __name__ == '__main__':
    main()

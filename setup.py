"""
This is a somewhat weird combination of a python package and brownie project.

it should probably be two seperate repos. hopefully it works out
"""
import setuptools

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

# read requirements.in instead of requirements.txt
# if we read requirements.txt, it can be difficult to use this as a library
# TODO: this doesn't work with `pip install -e` and have `-e` in requirements.in
with open("requirements.in", "r") as f:
    requirements = list(map(str.strip, f.read().split("\n")))

setuptools.setup(
    name="argobytes",
    version="0.0.2",
    author="Bryan Stitt",
    author_email="bryan@satoshiandkin.com",
    description="Python helpers for Argobytes",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/SatoshiAndKin/argobytes-contracts",
    packages=setuptools.find_packages(),
    install_requires=requirements,
    python_requires='>=3.6,<4',
    include_package_data=True,
    entry_points = {
        'console_scripts': [
            'argobytes=argobytes.cli:main',
        ],
        'argobytes.plugins': [
            'leverage_cyy3crv=argobytes.cli.leverage_cyy3crv:leverage_cyy3crv',
        ],
    },
)
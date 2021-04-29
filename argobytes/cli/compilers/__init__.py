import click


@click.group()
def compilers():
    """Manage EVM compilers."""


@compilers.command()
@click.option("--max-workers", type=int)
def download_all(max_workers):
    """Download all versions of solc and vyper."""
    from .download_all import download_all

    download_all(max_workers)

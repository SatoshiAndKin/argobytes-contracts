from concurrent.futures import ThreadPoolExecutor, as_completed

from click_spinner import spinner
from solcx import get_installable_solc_versions, install_solc
from vvm import get_installable_vyper_versions, install_vyper


def download_all(max_workers):
    """Download all versions of solc and vyper."""
    with spinner():
        solc_versions = get_installable_solc_versions()
        vyper_versions = get_installable_vyper_versions()

    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = [executor.submit(install_solc, version) for version in solc_versions]

        futures.extend(
            [executor.submit(install_vyper, version) for version in vyper_versions]
        )

        for _f in as_completed(futures):
            # TODO: check for errors
            pass

    print("All solc and vyper versions installed")

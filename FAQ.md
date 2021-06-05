# Why immutable owners?

1. So we can be allowed to do things like lock CRV for veCRV.
2. Because the way ERC-20 approvals work, transfering ownership could easily end up with funds being stolen.

# Can users own multiple proxies/clones?

Yes. They just need to set different salts when deploying their clone from the ArgobytesFactory19 contract.

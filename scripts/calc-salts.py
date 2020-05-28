# UNDER CONSTRUCTION
# Calculate salts for use with CREATE2.
# This can be used to create addresses with lots of zeros which are slightly cheaper to call.
# This can also be used for creating vanity addresses with fun patterns.

def main():
    address = "0x00000000000000000000000000000000deadbeef"
    # initcode is deployment bytecode + constructor params
    initcode = "0x00"

    print("ERADICATE2 -A", address, "-I", initcode, "--zeros")

    # first, we need to prompt what address is doing the deploy
    # if this is an EOA,
    #    then we get the current nonce for that address
    #    then we calculate what the contract address for ArgobytesOwnedVaultDeployer will be
    #    then we use ERADICATE2 to find a salt that gives an ArgobytesOwnedVault address with a lot of zeros
    #    then prompt for that salt
    # else we assume the address is the address for ArgobytesOwnedVault (or some other contract that can call create2 for us)

    # then we use ERADICATE2 to find a salt that gives all the other contract addresses lots of zeros when deployed from ArgobytesOwnedVault

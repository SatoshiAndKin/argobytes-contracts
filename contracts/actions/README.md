# Argobytes Actions

It is VITAL that you check the "to" to see if it is `address(0)`. If it is, you should set to to `msg.sender`
(This lets us use address(0) for the last call on every trade which saves gas and simplifies the caller's code)

Once we have easy traces on reverts and are ready for production, I think we can get rid of pretty much all requires and reverts in these. the actual exchanges all revert on invalid inputs and we only care that our balance increased. no need to sanitize inputs (beyond clear revert messages)

Debugging (needs a LONG timeout!):

    ```
    $ brownie console --network staging
    tx = network.transaction.TransactionReceipt("0xa2caf427dd83e18060d29a0a1bbe105dc08c98720df686474a3cddba054edb82")  
    tx.trace()
    ```

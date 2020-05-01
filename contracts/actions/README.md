# Argobytes Actions

It is VITAL that you check the "to" to see if it is `address(0)`. If it is, you should set to to `msg.sender`
(This lets us use address(0) for the last call on every trade which saves gas and simplifies the caller's code)

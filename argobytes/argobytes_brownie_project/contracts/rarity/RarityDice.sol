// SPDX-License-Identifier: MPL-2.0
pragma solidity 0.8.7;

contract RarityDice {
    // TODO: how do these work on the official contracts?
    // string constant public index = "Argobytes";
    // string constant public class = "Random";

    uint private counter = 0;

    function d100(uint _summoner) external returns (uint) {
        return dn(_summoner, 100);
    }

    function d20(uint _summoner) external returns (uint) {
        return dn(_summoner, 20);
    }

    function d12(uint _summoner) external returns (uint) {
        return dn(_summoner, 12);
    }

    function d10(uint _summoner) external returns (uint) {
        return dn(_summoner, 10);
    }

    function d8(uint _summoner) external returns (uint) {
        return dn(_summoner, 8);
    }

    function d6(uint _summoner) external returns (uint) {
        return dn(_summoner, 6);
    }

    function d4(uint _summoner) external returns (uint) {
        return dn(_summoner, 4);
    }

    function dn(uint _summoner, uint _number) public returns (uint) {
        return _random(_summoner) % _number + 1;
    }

    function random(uint _summoner) public returns (uint) {
        return _random(_summoner);
    }

    /** @notice INSECURE random number generator

        @dev
        Do not rely on block.timestamp or blockhash as a source of randomness, unless you know what you are doing (I probably don't).
        Both the timestamp and the block hash can be influenced by miners to some degree. Bad actors in the mining community can for example run a casino payout function on a chosen hash and just retry a different hash if they did not receive any money.
        The current block timestamp must be strictly larger than the timestamp of the last block, but the only guarantee is that it will be somewhere between the timestamps of two consecutive blocks in the canonical chain.
        The counter isn't sufficient either. Bad actors can reorder or inject extra transactions to change the counter. A per-summoner counter does not fix that.

        TODO: secure source of random. maybe https://docs.chain.link/docs/get-a-random-number/
    */
    function _random(uint _summoner) private returns (uint rand) {
        rand = uint(keccak256(abi.encodePacked(
            block.timestamp,
            blockhash(block.number - 1),
            counter,
            msg.sender,
            _summoner
        )));

        counter += 1;

        return rand;
    }
}

# [M-1] `OracleModule::_getPrice()` will revert if either one of the oracles fails, causing DOS

## Summary
In the current implementation of `OracleModule`, the `OracleModule::maxDiffPercent` is checked before the output from the Pyth oracle is checked for its validity. This means that if either of the two oracles returns incorrect results or stale prices, the whole transaction reverts. This not only defeats the purpose of having two oracles, but it also makes the `_getPrice()` function 25% more likely to revert.

## Vulnerability Detail
Even though the protocol uses two oracles, if either one of them returns incorrect prices and the price difference is greater than `OracleModule::maxDiffPercent`, the whole transaction will revert. This can cause DOS for users, keepers, and modules that are calling a lot of time-sensitive functions. Consider these scenarios:

1) Chainlink Oracle falters: In this case, the whole transaction will revert, thus no prices will be returned.

2) Pyth Oracle falters: In this case, the `offchainInvalid` parameter will be returned as false, but since the data is incorrect, let's assume that the returned offchainPrice is such that the onChainPrice difference and offChainPrice difference are greater than the `OracleModule::maxDiffPercent`. This means that this will also fail.

## Impact
A stale/incorrect price can cause the malfunction of multiple features across the protocol:

1) A lot of functions use `OracleModule::_getPrice()` to fetch the price of the tokens. Functions like `announceLeverageAdjust()`, `announceLeverageClose()`, `executeOpen()`, `executeClose()`, `liquidate()`, etc., many of which are time-sensitive functions.

2) Users/Keepers can miss out on liquidations, since the tokens that are used are volatile, the prices can shift a lot. So, if an oracle suddenly stops working and a position is undercollateralized, it won't be able to get liquidation until both of the oracles have started working properly.

3) If the problem persists, the protocol could remain in a paused state as all the actors would be DOSed and won't be able to do anything.

## Code Snippet
[Link to Code Snippet](https://github.com/sherlock-audit/2023-12-flatmoney/blob/main/flatcoin-v1/src/OracleModule.sol#L106-L137)

```solidity
function _getPrice(uint32 maxAge) internal view returns (uint256 price, uint256 timestamp) {
    (uint256 onchainPrice, uint256 onchainTime) = _getOnchainPrice(); // will revert if invalid
    (uint256 offchainPrice, uint256 offchainTime, bool offchainInvalid) = _getOffchainPrice();
    bool offchain;

    uint256 priceDiff = (int256(onchainPrice) - int256(offchainPrice)).abs();
    uint256 diffPercent = (priceDiff * 1e18) / onchainPrice;
    if (diffPercent > maxDiffPercent) revert FlatcoinErrors.PriceMismatch(diffPercent);

    if (offchainInvalid == false) {
        // return the freshest price
        if (offchainTime >= onchainTime) {
            price = offchainPrice;
            timestamp = offchainTime;
            offchain = true;
        } else {
            price = onchainPrice;
            timestamp = onchainTime;
        }
    } else {
        price = onchainPrice;
        timestamp = onchainTime;
    }

    // Check that the timestamp is within the required age
    if (maxAge < type(uint32).max && timestamp + maxAge < block.timestamp) {
        revert FlatcoinErrors.PriceStale(
            offchain ? FlatcoinErrors.PriceSource.OffChain : FlatcoinErrors.PriceSource.OnChain
        );
    }
}
```

## Tool used

Manual Review

## Recommendation

Consider returning another parameter `onchainInvalid` parameter from `_getOnchainPrice()` function call that tells if the price returned from the chainlink oracle is valid or not and a `lastGoodPrice` to store the most recent valid price that was obtained from the oracle . Change the checks to something like this 

```
if (price fetch on 1st oracle is successful and all of its own checks are passed) {
    lastGoodPrice = primaryOracle's fetchedPrice;
} 
else if(price fetch on 2nd oracle is successful and all of its own checks are passed) {
    lastGoodPrice = secondaryOracle's fetchedPrice;
    return lastGoodPrice;
}

return lastGoodPrice;

```
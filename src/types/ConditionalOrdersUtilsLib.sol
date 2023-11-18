// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

/**
 * @title ConditionalOrdersUtilsLib - Utility functions for standardising conditional orders.
 * @author mfw78 <mfw78@rndlabs.xyz>
 */
library ConditionalOrdersUtilsLib {
    uint256 constant MAX_BPS = 10000;

    /**
     * Given the width of the validity bucket, return the timestamp of the *end* of the bucket.
     * @param validity The width of the validity bucket in seconds.
     */
    function validToBucket(uint32 validity) internal view returns (uint32 validTo) {
        validTo = ((uint32(block.timestamp) / validity) * validity) + validity;
    }

    /**
     * Given a price returned by a chainlink-like oracle, scale it to the desired amount of decimals
     * @param oraclePrice return by a chainlink-like oracle
     * @param fromDecimals the decimals the oracle returned (e.g. 8 for USDC)
     * @param toDecimals the amount of decimals the price should be scaled to
     */
    function scalePrice(int256 oraclePrice, uint8 fromDecimals, uint8 toDecimals) internal pure returns (int256) {
        if (fromDecimals < toDecimals) {
            return oraclePrice * int256(10 ** uint256(toDecimals - fromDecimals));
        } else if (fromDecimals > toDecimals) {
            return oraclePrice / int256(10 ** uint256(fromDecimals - toDecimals));
        }
        return oraclePrice;
    }

    /**
     * Given an array of coordinates, and an x position, interpolate the y
     * value at the given x. Coordinates outside the given pairs are
     * extrapolated.
     * @param xs array of x coordinates
     * @param ys array of y coordinates
     * @param x coordinate to interpolate the y value for
     */
    function interpolate(int256[] memory xs, int256[] memory ys, int256 x) internal pure returns (int256) {
        require(xs.length > 0, "xs.length must be greater than 0");
        require(ys.length > 0, "ys.length must be greater than 0");
        require(xs.length == ys.length, "xs.length must equal ys.length");

        // Single x coordinate is treated as a flat line.
        if (xs.length == 1 && ys.length == 1) {
          return xs[0];
        }

        // Find the first pair which contains the target x
        int256 x0 = xs[0];
        int256 y0 = ys[0];
        int256 x1 = xs[1];
        int256 y1 = ys[1];
        for (uint i = 0; i < xs.length-1; i++) {
            if (x <= x1) {
                break;
            }
            x0 = xs[i];
            y0 = ys[i];
            x1 = xs[i+1];
            y1 = ys[i+1];
        }
        return ((y0 * (x1 - x)) + (y1 * (x - x0))) / (x1 - x0);
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "forge-std/Script.sol";

import {IERC20, IERC20Metadata} from "@openzeppelin/interfaces/IERC20Metadata.sol";

// Safe contracts
import {Safe} from "safe/Safe.sol";
import {Enum} from "safe/common/Enum.sol";
import "safe/proxies/SafeProxyFactory.sol";
import {CompatibilityFallbackHandler} from "safe/handler/CompatibilityFallbackHandler.sol";
import {MultiSend} from "safe/libraries/MultiSend.sol";
import {SignMessageLib} from "safe/libraries/SignMessageLib.sol";
import "safe/handler/ExtensibleFallbackHandler.sol";
import {SafeLib} from "../test/libraries/SafeLib.t.sol";

// Oracle
import "../src/interfaces/IAggregatorV3Interface.sol";

// Composable CoW
import "../src/ComposableCoW.sol";
import "../src/types/twap/TWAP.sol";
import {GoodAfterTime} from "../src/types/GoodAfterTime.sol";
import {PerpetualStableSwap} from "../src/types/PerpetualStableSwap.sol";
import {TradeAboveThreshold} from "../src/types/TradeAboveThreshold.sol";
import {StopLoss} from "../src/types/StopLoss.sol";

/**
 * @title Submit a single order to ComposableCoW
 * @author 0xAegir <paul@early.xyz>
 */
contract SubmitSingleStopLoss is Script {
    using SafeLib for Safe;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        Safe safe = Safe(payable(vm.envAddress("SAFE")));
        StopLoss stopLoss = StopLoss(vm.envAddress("STOP_LOSS"));
        ComposableCoW composableCow = ComposableCoW(vm.envAddress("COMPOSABLE_COW"));
        IAggregatorV3Interface sellTokenPriceOracle = IAggregatorV3Interface(vm.envAddress("SELL_TOKEN_PRICE_ORACLE"));
        IAggregatorV3Interface buyTokenPriceOracle = IAggregatorV3Interface(vm.envAddress("BUY_TOKEN_PRICE_ORACLE"));

        StopLoss.Data memory orderData = StopLoss.Data({
            sellToken: IERC20(address(0x1)),
            buyToken: IERC20(address(0x2)),
            sellTokenPriceOracle: sellTokenPriceOracle,
            buyTokenPriceOracle: buyTokenPriceOracle,
            strikeTimes: new int256[](0),
            strikePrices: new int256[](1),
            sellAmount: 10,
            buyAmount: 10,
            appData: bytes32(0x0),
            receiver: address(0),
            isSellOrder: false,
            isPartiallyFillable: false,
            validityBucketSeconds: 60 minutes,
            maxTimeSinceLastOracleUpdate: 15 minutes
        });

        vm.startBroadcast(deployerPrivateKey);

        // call to ComposableCoW to submit a single order
        safe.executeSingleOwner(
            address(composableCow),
            0,
            abi.encodeCall(
                composableCow.create,
                (
                    IConditionalOrder.ConditionalOrderParams({
                        handler: IConditionalOrder(stopLoss),
                        salt: keccak256(abi.encodePacked("STOP_LOSS")),
                        staticInput: abi.encode(orderData)
                    }),
                    true
                )
            ),
            Enum.Operation.Call,
            vm.addr(deployerPrivateKey)
        );

        vm.stopBroadcast();
    }
}

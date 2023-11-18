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
import {Limit4D} from "../src/types/Limit4D.sol";

/**
 * @title Submit a single order to ComposableCoW
 * @author 0xAegir <paul@early.xyz>
 */
contract SubmitSingleLimit4D is Script {
    using SafeLib for Safe;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        Safe safe = Safe(payable(vm.envAddress("SAFE")));
        Limit4D limit4D = Limit4D(vm.envAddress("LIMIT_4D"));
        ComposableCoW composableCow = ComposableCoW(vm.envAddress("COMPOSABLE_COW"));
        IAggregatorV3Interface sellTokenPriceOracle = IAggregatorV3Interface(vm.envAddress("SELL_TOKEN_PRICE_ORACLE"));
        IAggregatorV3Interface buyTokenPriceOracle = IAggregatorV3Interface(vm.envAddress("BUY_TOKEN_PRICE_ORACLE"));

        int256[] memory strikeTimes = new int256[](4);
        strikeTimes[0] = 0;
        strikeTimes[1] = 1700349021;
        strikeTimes[2] = 1700349022;
        strikeTimes[3] = type(int256).max;

        int256[] memory strikePrices = new int256[](4);
        strikePrices[0] = 0;
        strikePrices[1] = 0;
        strikePrices[2] = type(int256).max;
        strikePrices[3] = type(int256).max;


        Limit4D.Data memory orderData = Limit4D.Data({
            sellToken: IERC20(address(vm.envAddress("SELL_TOKEN"))),
            buyToken: IERC20(address(vm.envAddress("BUY_TOKEN"))),
            sellTokenPriceOracle: sellTokenPriceOracle,
            buyTokenPriceOracle: buyTokenPriceOracle,
            strikeTimes: strikeTimes,
            strikePrices: strikePrices,
            sellAmount: 1e18 / 10, // 0.1 dai
            buyAmount: 1, // min buy amount
            appData: bytes32(0x0),
            receiver: address(safe),
            isSellOrder: true,
            isPartiallyFillable: true,
            validityBucketSeconds: 15 minutes,
            maxTimeSinceLastOracleUpdate: 48 hours
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
                        handler: IConditionalOrder(limit4D),
                        salt: keccak256(abi.encodePacked("LIMIT_4D")),
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

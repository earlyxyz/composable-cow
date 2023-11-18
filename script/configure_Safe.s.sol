// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "forge-std/Script.sol";

// CoW Protocol
import {IWETH, WETH9} from "canonical-weth/WETH9.sol";
import {IAuthorizer, Authorizer} from "balancer/vault/Authorizer.sol";
import {Vault} from "balancer/vault/Vault.sol";
import {IVault as GPv2IVault} from "cowprotocol/interfaces/IVault.sol";
import "cowprotocol/GPv2Settlement.sol";
import "cowprotocol/GPv2AllowListAuthentication.sol";
import "cowprotocol/interfaces/GPv2Authentication.sol";

// Safe contracts
import {Safe} from "safe/Safe.sol";
import {Enum} from "safe/common/Enum.sol";
import "safe/proxies/SafeProxyFactory.sol";
import {CompatibilityFallbackHandler} from "safe/handler/CompatibilityFallbackHandler.sol";
import {MultiSend} from "safe/libraries/MultiSend.sol";
import {SignMessageLib} from "safe/libraries/SignMessageLib.sol";
import "safe/handler/ExtensibleFallbackHandler.sol";
import {SafeLib, TestAccount} from "../test/libraries/SafeLib.t.sol";
import {TestAccount, TestAccountLib} from "../test/libraries/TestAccountLib.t.sol";

// Composable CoW
import {ComposableCoW} from "../src/ComposableCoW.sol";
import {TWAP} from "../src/types/twap/TWAP.sol";
import {GoodAfterTime} from "../src/types/GoodAfterTime.sol";
import {PerpetualStableSwap} from "../src/types/PerpetualStableSwap.sol";
import {TradeAboveThreshold} from "../src/types/TradeAboveThreshold.sol";
import {StopLoss} from "../src/types/StopLoss.sol";
import {Limit4D} from "../src/types/Limit4D.sol";

contract ConfigureSafe is Script {
    using SafeLib for Safe;
    // --- constants
    uint256 constant PAUSE_WINDOW_DURATION = 7776000;
    uint256 constant BUFFER_PERIOD_DURATION = 2592000;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        ComposableCoW composableCow = ComposableCoW(vm.envAddress("COMPOSABLE_COW"));
        GPv2Settlement settlement = GPv2Settlement(payable(vm.envAddress("SETTLEMENT")));

        // deploy the Safe
        Safe safe = Safe(payable(vm.envAddress("SAFE")));
        ExtensibleFallbackHandler eHandler = ExtensibleFallbackHandler(vm.envAddress("EXTENSIBLE_FALLBACK_HANDLER"));

        vm.startBroadcast(deployerPrivateKey);

        safe.executeSingleOwner(
          address(safe),
          0x0,
          abi.encodeCall(
            safe.setFallbackHandler,
            (address(eHandler))
          ),
          Enum.Operation.Call,
          vm.addr(deployerPrivateKey)
        );

        safe.executeSingleOwner(
          address(safe),
          0x0,
          abi.encodeWithSelector(
              eHandler.setDomainVerifier.selector, settlement.domainSeparator(), address(composableCow)
          ),
          Enum.Operation.Call,
          vm.addr(deployerPrivateKey)
        );

        vm.stopBroadcast();
    }

}

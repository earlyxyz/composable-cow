# `Limit4D`: A new type of limit order

This repository builds on https://github.com/cowprotocol/composable-cow, adding
a new type of limit order. The 4-dimensional limit order. It is both extremely
simple and powerful.

The new order type is in
https://github.com/earlyxyz/composable-cow/blob/main/src/types/Limit4D.sol.

https://twitter.com/0xAegir/status/1726061870287585676

## Running the code

To open a Limit4D order, first follow the setup in https://github.com/cowprotocol/composable-cow.

Next, modify the deployment script in `script/submit_SingleLimit4D.s.sol`, to
have the order-type you want to execute. The parameters are similar to the basic
StopLoss order, but you'll want to edit the `strikeTimes`, and `strikePrices`,
to set the pricing curve for your order.

Then, to create the order run:
```sh
source .env

forge script \
    script/submit_SingleLimit4D.s.sol:SubmitSingleLimit4D \
    --rpc-url $ETH_RPC_URL \
    --broadcast
```

And to see the order execute, you can watch your account on: https://explorer.cow.fi

## Modelling different order types

Fundamentally, the innovation of Limit4D is that instead of taking a single
price and time window, it takes a list of coordinates as `(time, price)`.
In-between these times, it uses linear interpolation to determine the strike
price.

For example, if you had the following list of coordinates `(t0, 1) -> (t10, 2)`,
then at `t5`, the interpolated strike price would be `1.5`.

By "rasterizing" different pricing curves into lists of coordinates, we can use
a single 4D Limit order to model lots of different order types.

### Normal Limit Order

In this case, we only provide a single coordinate tuple. For example:

`(now, price)`

Limit4D will interpret this as a flat line pricing.

### Market Order

For a market order, we can pick an execution time, and then around that time, we drop the price so that the order is fulfilled instantly.

Before the desired execution time, the price is `(before, infinite)`, and after it goes to `(after, 0)`.

### Dutch Auction

To simulate a dutch auction, we start our price high, and end the price low.

`(auctionStartTime, highAuctionStartPrice) -> (auctionEndTime, lowAuctionEndPrice)`

As the price decreases, the order will be filled whenever the price intersects
the current market rate. The dutch auction is useful when selling an asset.

### Normal Auction

The opposite of a dutch auction. Useful when buying an asset.

You start the price low, and increase it until reaching your maximum bid.

`(auctionStartTime, minimumBid) -> (auctionEndTime, maximumBid)`

### Automatically Trading Ascending/Descending Channels

By using two 4D Limit orders together, you can automatically trade across a
range. Even if that range is an ascending or descending channel.

To do this you would set up one order to sell when the price moves above the
channel, and a second one to buy when it moves below.

### And More...

There are probably many other trade preferences you can model with 4D Limit
Orders. These are just a few ideas.

## Data Structure

```solidity=
struct Data {
    IERC20 sellToken;
    IERC20 buyToken;
    address receiver; // address(0) if the safe
    uint256 sellAmount;
    uint256 buyAmount;
    bytes32 appData;
    bool isSellOrder;
    bool isPartiallyFillable;
    uint32 validityBucketSeconds;
    IAggregatorV3Interface sellTokenPriceOracle;
    IAggregatorV3Interface buyTokenPriceOracle;
    int256[] strikeTimes;
    int256[] strikePrices;
    uint256 maxTimeSinceLastOracleUpdate;
}
```

## Developers

### Requirements

- `forge` ([Foundry](https://github.com/foundry-rs/foundry))

### Deployed Contracts

| Contract Name                  | Gnosis Chain                                                                                                           |
| ------------------------------ | ---------------------------------------------------------------------------------------------------------------------- |
| `Limit4D`                     | [0x13836e7B843c5BA401E69Cf1D4B21CaFcE0aa623](https://gnosisscan.io/address/0x13836e7B843c5BA401E69Cf1D4B21CaFcE0aa623) |

### Environment setup

Copy the `.env.example` to `.env` and set the applicable configuration variables for the testing / deployment environment.

### Testing

**NOTE:** Fuzz tests also include a `simulate` that runs full end-to-end integration testing, including the ability to settle conditional orders. Fork testing simulates end-to-end against production ethereum mainnet contracts, and as such requires `ETH_RPC_URL` to be defined (this should correspond to an archive node).

```bash
forge test -vvv --no-match-test "fork|[fF]uzz" # Basic unit testing only
forge test -vvv --no-match-test "fork" # Unit and fuzz testing
forge test -vvv # Unit, fuzz, and fork testing
```

### Coverage

```bash
forge coverage -vvv --no-match-test "fork" --report summary
```

### Deployment

Deployment is handled by solidity scripts in `forge`. The network being deployed to is dependent on the `ETH_RPC_URL`.

```bash
source .env
# Deploy ComposableCoW
forge script script/deploy_ComposableCoW.s.sol:DeployComposableCoW --rpc-url $ETH_RPC_URL --broadcast -vvvv --verify
# Deploy order types
forge script script/deploy_OrderTypes.s.sol:DeployOrderTypes --rpc-url $ETH_RPC_URL --broadcast -vvvv --verify
```

#### Local deployment

For local integration testing, including the use of [Watch Tower](https://github.com/cowprotocol/tenderly-watch-tower), it may be useful deploying to a _forked_ mainnet environment. This can be done with `anvil`.

1. Open a terminal and run `anvil`:

   ```bash
   anvil --code-size-limit 50000 --block-time 5
   ```

   **NOTE**: When deploying the full stack on `anvil`, the balancer vault may exceed contract code size limits necessitating the use of `--code-size-limit`.

2. Follow the previous deployment directions, with this time specifying `anvil` as the RPC-URL:

   ```bash
   source .env
   forge script script/deploy_AnvilStack.s.sol:DeployAnvilStack --rpc-url http://127.0.0.1:8545 --broadcast -vvvv
   ```

   **NOTE**: Within the output of the above command, there will be an address for a `Safe` that was deployed to `anvil`. This is needed for the next step.

   **NOTE:** `--verify` is omitted as with local deployments, these should not be submitted to Etherscan for verification.

3. To then simulate the creation of a single order:

   ```bash
   source .env
   SAFE="address here" forge script script/submit_SingleLimit4D.s.sol:SubmitSingleLimit4D --rpc-url http://127.0.0.1:8545 --broadcast
   ```

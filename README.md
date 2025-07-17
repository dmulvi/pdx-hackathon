# PDX Hackathon - Perpin' Ain't Easy

Start up the system with:

```bash
anvil --load-state anvilState-pdx.json
```

You can use these commands to test out the system a bit. The `liquidatePosition` call will be reverted by the rules engine for example because the address you pass does not have an open position.

```bash
cast send $PERPS_ENGINE "addCollateralForSelf(uint256)" 123456 --private-key $PRIV_KEY
cast call $PERPS_ENGINE "getFreeCollateral(address)(uint256)" $USER_ADDRESS
cast send $PERPS_ENGINE "liquidatePosition(address)" 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65 --private-key $PRIV_KEY
```

Here is a command to open a new position for the second anvil account: (note the private key used)

```bash
cast send $PERPS_ENGINE "openPosition(uint256,uint256,uint256,uint8)" 1000000000000000000000 100000000000000000000 10 0 --private-key 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
```

Now try to close a position for an account that does have one: (this isn't working due to a divde by zero error that needs to be fixed)

```bash
cast send $PERPS_ENGINE "liquidatePosition(address)" $USER_ADDRESS --private-key $PRIV_KEY
```

## Already completed setup below

All of these commands have already been run and the results are included in the `anvilState-pdx.json` file.

Deploy the Mock Price Oracle

```bash
forge script script/MockPriceOracle.s.sol --ffi --broadcast -vvv --non-interactive --rpc-url $RPC_URL --private-key $PRIV_KEY
```

Deploy the Perps Engine Contract

```bash
forge script script/FortePerpsEngine.s.sol --ffi --broadcast -vvv --non-interactive --rpc-url $RPC_URL --private-key $PRIV_KEY
```

Now, open some positions

```bash
cast send $PERPS_ENGINE "openPosition(uint256,uint256,uint256,uint8)" 1000000000000000000000 100000000000000000000 10 0 --private-key $PRIV_KEY
# 1000 USD size (in wei, assuming 18 decimals)
# 100 USD collateral (10% of size for 10x leverage)
# 10x leverage
# 0 = LONG position, 1 = SHORT position
```

Misc commands:

```bash
cast send $PERPS_ENGINE "setRulesEngineAddress(address)" $RULES_ENGINE_ADDRESS --private-key $PRIV_KEY
cast send $PERPS_ENGINE "setCallingContractAdmin(address)" $USER_ADDRESS --rpc-url $RPC_URL --private-key $PRIV_KEY
```

```bash
npx tsx index.ts applyPolicy $POLICY_ID $PERPS_ENGINE
```

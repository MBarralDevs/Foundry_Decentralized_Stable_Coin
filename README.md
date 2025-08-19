🏦 Decentralized Stablecoin Protocol (Foundry)

A fully on-chain overcollateralized stablecoin system, inspired by MakerDAO’s DAI, built with Solidity and the Foundry framework.
This project showcases best practices in smart contract architecture, testing (unit, fuzz, invariant), and deployment scripting.

📌 Overview

This protocol allows users to:

Deposit collateral (WETH, WBTC).

Mint a USD-pegged stablecoin (DSC) against their collateral.

Maintain safety via health factor enforcement (overcollateralization).

Be liquidated if their position becomes undercollateralized.

The stablecoin is always backed by more USD value in collateral than the total DSC supply, enforced by invariants.

⚙️ Features

Mint / Burn DSC → Users mint stablecoins against collateral and burn to repay debt.

Deposit / Redeem Collateral → Locked collateral ensures solvency.

Oracle Integration → Chainlink-style price feeds with safety checks (via OracleLib).

Liquidations → Keep system solvent by rewarding liquidators with collateral.

Invariant Testing → Ensures protocol safety assumptions always hold.

📂 Architecture
graph TD
    U[User] --> |Deposit WETH/WBTC| E[DSCEngine]
    U --> |Mint DSC| E
    U --> |Burn DSC| E
    U --> |Redeem Collateral| E
    E --> |Health Factor Enforcement| HF[Health Factor >= 1]
    E --> |Price Feeds| O[OracleLib -> Chainlink Aggregators]
    E --> |Transfers Ownership| DSC[DecentralizedStableCoin]
    L[Liquidator] --> |Covers Debt + Liquidates| E


Core Contracts

DecentralizedStableCoin.sol → ERC20 stablecoin implementation.

DSCEngine.sol → Core logic: collateral management, minting, burning, liquidations.

OracleLib.sol → Price safety wrapper for Chainlink-style oracles.

Deployment

DeployDSC.s.sol → Deploys DSC + DSCEngine + configures collateral.

HelperConfig.s.sol → Network-aware deployment (local mocks vs Sepolia addresses).

🧪 Testing

The project uses Foundry’s forge-std for advanced testing.

Unit Tests

DSCEngine.t.sol → Minting, collateral deposit, liquidation logic.

DecentralizedStableCoin.t.sol → ERC20 compliance, mint/burn permissions.

OracleLib.t.sol → Oracle edge cases & reverts.

Mock Tests

MockV3Aggregator.t.sol → Price feed manipulation.

ERC20Mock.t.sol → Collateral token simulations.

Fuzz Tests

Randomized inputs for collateral deposits, minting, redemptions.

Invariant Tests

Located in /test/fuzz/failOnRevert:

FailOnRevertHandler.t.sol → Defines actions: mint, deposit, redeem, burn, liquidate.

FailOnRevertInvariant.t.sol → Ensures:

Protocol must always have more collateral value than DSC supply.

Getters cannot revert.

Run tests with:

forge test

🚀 Deployment
Local (Anvil)

Deploys with mocks for WETH/WBTC and price feeds.

forge script script/DeployDSC.s.sol --fork-url http://127.0.0.1:8545 --broadcast

Sepolia Testnet

Uses real ERC20 test tokens & Chainlink price feeds.
Requires .env with PRIVATE_KEY.

forge script script/DeployDSC.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify

🔐 Security Model

Overcollateralization → Health factor enforces that collateral value > debt.

Price Oracles → Chainlink-style with sanity checks.

Liquidations → Incentivized to restore solvency.

Invariant Testing → System-wide guarantees (collateral value ≥ total DSC).

📈 Future Improvements

Governance for collateral onboarding.

Support for more collateral assets.

Peg stability mechanisms (AMMs, interest rates).

Frontend for user interaction.

Formal verification.

🛠️ Tech Stack

Solidity 0.8.18

Foundry (forge, cast, anvil)

Chainlink Oracles

OpenZeppelin ERC20

📜 License

MIT © 2025

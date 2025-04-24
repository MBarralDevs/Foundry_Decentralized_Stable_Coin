// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployDSC} from "script/DeployDSC.s.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {FailOnRevertHandler} from "test/fuzz/failOnRevert/FailOnRevertHandler.t.sol";

contract FailOnRevertInvariant is StdInvariant, Test {
    // This contract is used to test the invariant of the Handler contract.

    DeployDSC deployer;
    DSCEngine dscEngine;
    DecentralizedStableCoin dsc;
    HelperConfig config;
    address weth;
    address wbtc;
    FailOnRevertHandler handler;

    function setUp() external {
        deployer = new DeployDSC();
        (dsc, dscEngine, config) = deployer.run();
        (,, weth, wbtc,) = config.activeNetworkConfig();
        handler = new FailOnRevertHandler(dscEngine, dsc);
        targetContract(address(handler));
    }

    //We check here if the total supply of DSC is less than the total value of WETH and WBTC in the protocol.
    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
        uint256 totalSupply = dsc.totalSupply();
        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(dscEngine));
        uint256 totalWbtcDeposited = IERC20(wbtc).balanceOf(address(dscEngine));

        uint256 totalWethValue = dscEngine.getUsdValue(weth, totalWethDeposited);
        uint256 totalWbtcValue = dscEngine.getUsdValue(wbtc, totalWbtcDeposited);

        console.log("Total supply : ", totalSupply);
        console.log("Total WETH value : ", totalWethValue);
        console.log("Total WBTC value : ", totalWbtcValue);
        console.log("Time mint function called : ", handler.getTimeMintDscIsCalled());

        assert(totalWethValue + totalWbtcValue >= totalSupply);
    }

    function invariant_gettersCantRevert() public view {
        dscEngine.getAdditionalFeedPrecision();
        dscEngine.getCollateralTokens();
        dscEngine.getLiquidationBonus();
        dscEngine.getLiquidationThreshold();
        dscEngine.getMinHealthFactor();
        dscEngine.getPrecision();
    }
}

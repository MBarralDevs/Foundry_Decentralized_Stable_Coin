// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../../mocks/MockV3Aggregator.sol";

contract FailOnRevertHandler is Test {
    DSCEngine dscEngine;
    DecentralizedStableCoin dsc;
    ERC20Mock weth;
    ERC20Mock wbtc;

    uint256 public timeMintDscIsCalled = 0;
    address[] public usersWithCollateralDeposited;
    MockV3Aggregator public ethUsdPriceFeed;
    MockV3Aggregator public btcUsdPriceFeed;

    uint256 constant MAX_COLLATERAL = type(uint96).max;

    constructor(DSCEngine _dscEngine, DecentralizedStableCoin _dsc) {
        dscEngine = _dscEngine;
        dsc = _dsc;

        address[] memory collateralTokens = dscEngine.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);

        ethUsdPriceFeed = MockV3Aggregator(dscEngine.getCollateralTokenPriceFeed(address(weth)));
        btcUsdPriceFeed = MockV3Aggregator(dscEngine.getCollateralTokenPriceFeed(address(wbtc)));
    }

    //Mint and Deposit collateral handler function that will chose the cases we want to test
    function mintAndDepositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        amountCollateral = bound(amountCollateral, 1, MAX_COLLATERAL); // Make it impossible to have a 0 amount collateral
        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(dscEngine), amountCollateral);
        dscEngine.depositCollateral(address(collateral), amountCollateral);
        vm.stopPrank();
        usersWithCollateralDeposited.push(msg.sender);
    }

    //Redeem Collateral handler function
    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        //We check if our msg.sender has collateral to redeem
        if (!doesSenderHaveCollateralToRedeem(msg.sender)) {
            return;
        }

        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        uint256 maxCollateral = (dscEngine.getCollateralBalanceOfUser(msg.sender, address(collateral)) / 2);
        amountCollateral = bound(amountCollateral, 0, maxCollateral);
        if (amountCollateral == 0) {
            return;
        }

        //But we also need to prevent, depending on the amount of collateral we want to redeem, to go below the minimum health factor
        //For that we need to calculate our health factor depending on the amount of collateral we want to redeem
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dscEngine.getAccountInformations(msg.sender);
        uint256 minHealthFactor = dscEngine.getMinHealthFactor();
        //We want our amount of collateral to redeem in USD
        uint256 amountCollateralToRedeemInUsd = dscEngine.getUsdValue(address(collateral), amountCollateral);

        uint256 healthFactorAfterRedeem =
            dscEngine.calculateHealthFactor(totalDscMinted, collateralValueInUsd - amountCollateralToRedeemInUsd);

        //We check if our health factor after redeem is above the minimum
        if (healthFactorAfterRedeem < minHealthFactor) {
            return;
        }

        vm.prank(msg.sender);
        dscEngine.redeemCollateral(address(collateral), amountCollateral);
    }

    //burn dsc function
    function burnDsc(uint256 amountDsc) public {
        // Must burn more than 0
        amountDsc = bound(amountDsc, 0, dsc.balanceOf(msg.sender));
        if (amountDsc == 0) {
            return;
        }
        vm.startPrank(msg.sender);
        dsc.approve(address(dscEngine), amountDsc);
        dscEngine.burnDsc(amountDsc);
        vm.stopPrank();
    }

    //Mintfunction
    function mintDsc(uint256 amount, uint256 addressSeed) public {
        if (usersWithCollateralDeposited.length == 0) {
            return;
        }
        address sender = usersWithCollateralDeposited[addressSeed % usersWithCollateralDeposited.length];
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dscEngine.getAccountInformations(sender);
        int256 maxDscToMint = (int256(collateralValueInUsd / 2) - int256(totalDscMinted));

        if (maxDscToMint <= 0) {
            return;
        }
        amount = bound(amount, 1, uint256(maxDscToMint));
        if (amount == 0) {
            return;
        }

        vm.prank(sender);
        dscEngine.mintDsc(amount);
        timeMintDscIsCalled++;
    }

    function liquidate(uint256 collateralSeed, address userToBeLiquidated, uint256 debtToCover) public {
        uint256 minHealthFactor = dscEngine.getMinHealthFactor();
        uint256 userHealthFactor = dscEngine.getHealthFactor(userToBeLiquidated);
        if (userHealthFactor >= minHealthFactor) {
            return;
        }
        debtToCover = bound(debtToCover, 1, uint256(type(uint96).max));
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        vm.prank(msg.sender);
        dscEngine.liquidate(address(collateral), userToBeLiquidated, debtToCover);
    }

    /*function updateCollateralPrice(uint96 newPrice, uint256 collateralSeed) public {
        int256 newPriceInt = int256(uint256(newPrice));
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        MockV3Aggregator priceFeed = MockV3Aggregator(dscEngine.getCollateralTokenPriceFeed(address(collateral)));
        priceFeed.updateAnswer(newPriceInt);
    }*/

    /// Helper Functions
    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return weth;
        } else {
            return wbtc;
        }
    }

    function doesSenderHaveCollateralToRedeem(address sender) private view returns (bool) {
        for (uint256 i = 0; i < usersWithCollateralDeposited.length; i++) {
            if (usersWithCollateralDeposited[i] == sender) {
                return true;
            }
        }
        return false;
    }

    function getTimeMintDscIsCalled() public view returns (uint256) {
        return timeMintDscIsCalled;
    }
}

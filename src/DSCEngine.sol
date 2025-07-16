// SPDX-License-Identifier: MIT

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";

import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

pragma solidity ^0.8.19;

/**
 * @title DSC Engine
 *   @author @0xvishh
 *
 *   this sytem is designed to be as minimal as possible and have the tokens maintain a 1 token == 1$ peg.
 *   this stablecoin has the properties :
 *   - Exogenous collateral
 *   - Dollar Pegged
 *   - Algorthmically stable
 *
 *   its is similar to DAI if DAI had no governance, no fees and only backed by wETH and wBTC.
 *   @notice this contract is the core of the DSC system it handles all the logic for mining and redeeming DSC, as well as depositing and withdrawing collateral.
 *   @notice this contract is very loosely based on MAKERDAO DSS (DAI) system.
 */
contract DSCEngine is ReentrancyGuard {
    error DSCEngine__NeedMoreThanZero();
    error DSCEngine__TokenAddressAndPriceFeedAddressesMustBeSameLength();
    error DSCEngine__NotAllowedToken();
    error DSCEngine__TransferFailed();

    DecentralizedStableCoin private immutable i_Dsc;

    mapping(address token => address priceFeed) private s_priceFeed;
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;

    event collateralDeposited(address indexed user, address indexed token, uint256 indexed amount);

    modifier MoreThanZero(uint256 _amount) {
        if (_amount == 0) {
            revert DSCEngine__NeedMoreThanZero();
        }
        _;
    }

    modifier allowedTokens(address _token) {
        if (s_priceFeed[_token] == address(0)) {
            revert DSCEngine__NotAllowedToken();
        }
        _;
    }

    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address dscAddress) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressAndPriceFeedAddressesMustBeSameLength();
        }
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeed[tokenAddresses[i]] = priceFeedAddresses[i];
        }
        i_Dsc = DecentralizedStableCoin(dscAddress);
    }

    function depositCollateralAndMintDsc() external {}

    /**
     *   @notice follows CEI - Checks - effects - interaction pattern
     *   @param _tokenCollateralAddress the address of the token to deposit as collateral
     *   @param _amountCollateral the amoount of collateral to deposit
     */
    function depostCollateral(address _tokenCollateralAddress, uint256 _amountCollateral)
        external
        MoreThanZero(_amountCollateral)
        allowedTokens(_tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][_tokenCollateralAddress] += _amountCollateral;
        emit collateralDeposited(msg.sender, _tokenCollateralAddress, _amountCollateral);
        bool success = IERC20(_tokenCollateralAddress).transferFrom(msg.sender, address(this), _amountCollateral);
        if (!success){
            revert DSCEngine__TransferFailed();
        }
    }

    function redeemCollateralForDsc() external {}

    function redeemCollateral() external {}

    function mintDsc() external {}

    function burnDsc() external {}

    function liquiDate() external {}

    function getHealthFactor() external view {}
}

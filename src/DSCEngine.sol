// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from
    "lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

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
    error DSCEngine__BreaksHealthFactor();
    error DSCEngine__MintFailed();

    DecentralizedStableCoin private immutable i_Dsc;

    uint256 private constant ADDITION_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MINIMUM_HEALTHFACTOR = 1;

    mapping(address token => address priceFeed) private s_priceFeed;
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amountMinted) private s_DSCMinted;

    address[] private s_collateralToken;

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
            s_collateralToken.push(tokenAddresses[i]);
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
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function redeemCollateralForDsc() external {}

    function redeemCollateral() external {}

    function mintDsc(uint256 _amountDscToMint) external MoreThanZero(_amountDscToMint) {
        s_DSCMinted[msg.sender] += _amountDscToMint;
        _revertIfHealthfactorIsBroken(msg.sender);
        bool minted = i_Dsc.mint(msg.sender, _amountDscToMint);
        if (!minted) {
            revert DSCEngine__MintFailed();
        }
    }

    function burnDsc() external {}

    function liquiDate() external {}

    function getHealthFactor() external view {}

    // PRIVATE & INTERNAL FUNCTION //

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        totalDscMinted = s_DSCMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    /**
     * returns how close the liquidation a user is
     *   if a user goes below 1, then they get liquidated
     */
    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        uint256 collateralAdjustedForTreshold = (collateralValueInUsd * totalDscMinted) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForTreshold * PRECISION) / totalDscMinted;
        // return (collateralValueInUsd / totalDscMinted);
    }

    // check healthFactor (do they have enough collateral)
    // revert if they dont
    function _revertIfHealthfactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MINIMUM_HEALTHFACTOR) {
            revert DSCEngine__BreaksHealthFactor();
        }
    }

    // PUBLIC & EXTERNAL FUNCTION //

    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        for (uint256 i = 0; i < s_collateralToken.length; i++) {
            address token = s_collateralToken[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeed[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return ((uint256(price) * ADDITION_FEED_PRECISION) * amount) / PRECISION;
    }
}

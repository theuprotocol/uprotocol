// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {InitializableERC20} from "./InitializableERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {CapToken} from "./CapToken.sol";

contract UpToken is InitializableERC20 {
    using SafeERC20 for IERC20Metadata;

    IERC20Metadata public underlyingToken;
    IERC20Metadata public settlementToken;
    address public capToken;
    uint256 public strike;
    uint256 public expiry;

    error InvalidInitValues();
    error Expired();
    error PreExpiry();

    function initialize(
        IERC20Metadata _underlyingToken,
        IERC20Metadata _settlementToken,
        address _capToken,
        uint256 _strike,
        uint256 _expiry,
        address to,
        uint256 amount
    ) external initializer {
        if (_expiry < block.timestamp || _strike == 0) {
            revert InvalidInitValues();
        }
        decimals = IERC20Metadata(_underlyingToken).decimals();
        name = IERC20Metadata(_underlyingToken).name();
        symbol = IERC20Metadata(_underlyingToken).symbol();
        underlyingToken = _underlyingToken;
        settlementToken = _settlementToken;
        capToken = _capToken;
        strike = _strike;
        expiry = _expiry;
        if (to == address(0) || amount > 0) {
            _mint(to, amount);
            CapToken(capToken).mint(to, amount);
            underlyingToken.safeTransferFrom(msg.sender, address(this), amount);
        }
    }

    function mint(address to, uint256 amount) external {
        if (block.timestamp > expiry) {
            revert Expired();
        }
        _mint(to, amount);
        CapToken(capToken).mint(to, amount);
        underlyingToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    function exercise(uint256 amount) external {
        if (block.timestamp > expiry) {
            revert Expired();
        }
        uint256 payPrice = (amount * strike) /
            (10 ** IERC20Metadata(underlyingToken).decimals());
        underlyingToken.safeTransfer(msg.sender, amount);
        settlementToken.safeTransferFrom(msg.sender, address(this), payPrice);
        _burn(msg.sender, amount);
    }

    function redeemUnderlying(uint256 amount) external {
        if (block.timestamp <= expiry) {
            revert PreExpiry();
        }
        underlyingToken.safeTransfer(msg.sender, amount);
        CapToken(capToken).burn(msg.sender, amount);
    }

    function claimSettlement(uint256 amount) external {
        if (block.timestamp <= expiry) {
            revert PreExpiry();
        }
        uint256 nominator = settlementToken.balanceOf(address(this)) *
            CapToken(capToken).balanceOf(msg.sender);
        uint256 denominator = CapToken(capToken).totalSupply();
        uint256 proRataShare = nominator / denominator;
        underlyingToken.safeTransfer(msg.sender, proRataShare);
        CapToken(capToken).burn(msg.sender, amount);
    }
}

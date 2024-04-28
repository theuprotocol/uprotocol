// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {InitializableERC20} from "../utils/InitializableERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {CapToken} from "./CapToken.sol";

contract UpToken is InitializableERC20 {
    using SafeERC20 for IERC20Metadata;

    address public underlyingToken;
    address public settlementToken;
    address public capToken;
    uint256 public strike;
    uint256 public expiry;

    error InvalidInitValues();
    error Expired();
    error PreExpiry();

    function initialize(
        address _underlyingToken,
        address _settlementToken,
        address _capToken,
        uint256 _strike,
        uint256 _expiry,
        address to,
        uint256 underlyingAmount
    ) external initializer {
        if (
            _expiry < block.timestamp ||
            _strike == 0 ||
            to == address(0) ||
            underlyingAmount == 0
        ) {
            revert InvalidInitValues();
        }
        decimals = 18;
        name = IERC20Metadata(_underlyingToken).name();
        symbol = IERC20Metadata(_underlyingToken).symbol();
        underlyingToken = _underlyingToken;
        settlementToken = _settlementToken;
        capToken = _capToken;
        strike = _strike;
        expiry = _expiry;
        uint256 mintAmount = underlyingAmount *
            10 ** (18 - IERC20Metadata(_underlyingToken).decimals());
        _mint(to, mintAmount);
        CapToken(capToken).mint(to, mintAmount);
        IERC20Metadata(_underlyingToken).approve(capToken, type(uint256).max);
    }

    function tokenize(address to, uint256 underlyingAmount) external {
        if (block.timestamp > expiry) {
            revert Expired();
        }
        address _underlyingToken = underlyingToken;
        uint256 mintAmount = underlyingAmount *
            10 ** (18 - IERC20Metadata(_underlyingToken).decimals());
        _mint(to, mintAmount);
        CapToken(capToken).mint(to, mintAmount);
        IERC20Metadata(_underlyingToken).safeTransferFrom(
            msg.sender,
            address(this),
            underlyingAmount
        );
    }

    function untokenize(address to, uint256 amount) external {
        _burn(msg.sender, amount);
        CapToken(capToken).burn(msg.sender, amount);
        IERC20Metadata(underlyingToken).safeTransfer(to, amount);
    }

    function exercise(address to, uint256 amount) external {
        // @dev: exercising is possible only until and including expiry
        if (block.timestamp > expiry) {
            revert Expired();
        }
        uint256 payPrice = (amount * strike) / (10 ** decimals);
        uint256 transferOutAmount;
        uint256 _totalSupply = totalSupply();
        uint256 _totalBal = IERC20Metadata(underlyingToken).balanceOf(
            address(this)
        );
        if (amount == _totalSupply) {
            transferOutAmount = _totalBal;
        } else {
            transferOutAmount = (_totalBal * amount) / _totalSupply;
        }
        IERC20Metadata(underlyingToken).safeTransfer(to, transferOutAmount);
        IERC20Metadata(settlementToken).safeTransferFrom(
            msg.sender,
            capToken,
            payPrice
        );
        _burn(msg.sender, amount);
    }

    function redeem(address to, uint256 amount) external {
        uint256 transferOutAmount;
        uint256 _totalSupply = totalSupply();
        uint256 _totalBal = IERC20Metadata(underlyingToken).balanceOf(
            address(this)
        );
        if (amount == _totalSupply) {
            transferOutAmount = _totalBal;
        } else {
            transferOutAmount = (_totalBal * amount) / _totalSupply;
        }
        _burn(msg.sender, amount);
        CapToken(capToken).burn(msg.sender, amount);
        IERC20Metadata(underlyingToken).safeTransfer(to, transferOutAmount);
    }

    function totalExercisable() external view returns (uint256) {
        return
            IERC20Metadata(underlyingToken).balanceOf(address(this)) -
            totalUnexercised();
    }

    function exercisable(address account) external view returns (uint256) {
        if (block.timestamp <= expiry) {
            return
                (IERC20Metadata(underlyingToken).balanceOf(address(this)) *
                    balanceOf(account)) / totalSupply();
        }
        return 0;
    }

    function totalUnexercised() public view returns (uint256) {
        if (block.timestamp > expiry) {
            return IERC20Metadata(underlyingToken).balanceOf(address(this));
        }
        return 0;
    }
}

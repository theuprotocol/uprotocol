// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {InitializableERC20} from "./InitializableERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {UpToken} from "./UpToken.sol";

contract Pool is InitializableERC20 {
    using SafeERC20 for IERC20Metadata;

    uint256 constant SECONDS_PER_WEEK = 604_800;
    uint256 constant BASE = 1e8;

    address public underlyingToken;
    address public capToken;

    uint256 public xUnd;
    uint256 public yCap;

    uint256 public a;
    uint256 public b;
    uint256 public k;
    uint256 public expiry;

    error InvalidInitValues();
    error InsufficientLiquidity();

    function initialize(
        address _upToken,
        uint256 x0y0,
        uint256 _a,
        uint256 _b,
        address to
    ) external initializer {
        if (UpToken(_upToken).expiry() < block.timestamp) {
            revert InvalidInitValues();
        }
        address _underlyingToken = address(UpToken(_upToken).underlyingToken());
        capToken = UpToken(_upToken).capToken();
        underlyingToken = _underlyingToken;
        decimals = IERC20Metadata(_underlyingToken).decimals();
        name = IERC20Metadata(_underlyingToken).name();
        symbol = IERC20Metadata(_underlyingToken).symbol();
        expiry = UpToken(_upToken).expiry();
        xUnd = x0y0;
        yCap = x0y0;
        a = _a;
        b = _b;
        k = getK(x0y0, x0y0, _a, _b, _secondsLeft());
        _mint(to, x0y0);
    }

    function swapXUnderlyingForYCap(
        address to,
        uint256 xUndIn
    ) external returns (uint256) {
        uint256 _xUndMax = xUndMax();
        uint256 xNew = xUnd + xUndIn;
        if (xNew >= _xUndMax) {
            revert InsufficientLiquidity();
        }
        uint256 yNew = getYCap(xNew, a, b, _secondsLeft(), k);
        uint256 yOut = yCap - yNew;
        xUnd = xNew;
        yCap = yNew;
        IERC20Metadata(capToken).safeTransfer(to, yOut);
        IERC20Metadata(underlyingToken).safeTransferFrom(
            msg.sender,
            address(this),
            xUndIn
        );
        return yOut;
    }

    function swapYCapForXUnderlying(
        uint256 yCapIn
    ) external returns (uint256) {}

    function addLiquidity() external returns (uint256) {}

    function removeLiquidity() external returns (uint256) {}

    function xUndMax() public view returns (uint256) {
        uint256 _k = k;
        uint256 _a = a;
        uint256 _b = b;
        return
            _k /
            (2 * (BASE + _a)) +
            Math.sqrt(
                Math.mulDiv(_k, _k, 4 * (BASE + _a) ** 2) +
                    (_b * Math.sqrt(_secondsLeft()) * _k) /
                    Math.sqrt(SECONDS_PER_WEEK) /
                    (BASE + _a)
            );
    }

    function getYCap(
        uint256 _xUnd,
        uint256 _a,
        uint256 _b,
        uint256 _t,
        uint256 _k
    ) public pure returns (uint256) {
        return
            Math.mulDiv(
                _b,
                Math.sqrt(_t) * _k,
                _xUnd * Math.sqrt(SECONDS_PER_WEEK)
            ) -
            (_a * _xUnd) /
            BASE +
            _k;
    }

    function getK(
        uint256 _xUnd,
        uint256 _yCap,
        uint256 _a,
        uint256 _b,
        uint256 _t
    ) public pure returns (uint256) {
        return
            Math.mulDiv(
                _xUnd,
                (_a * _xUnd) / BASE + _yCap,
                (_b * Math.sqrt(_t)) /
                    Math.sqrt(SECONDS_PER_WEEK) /
                    BASE +
                    _xUnd
            );
    }

    function _secondsLeft() internal view returns (uint256) {
        uint256 _expiry = expiry;
        return _expiry > block.timestamp ? _expiry - block.timestamp : 0;
    }
}

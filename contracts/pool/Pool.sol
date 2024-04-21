// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {InitializableERC20} from "../utils/InitializableERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {UpToken} from "../tokenization/UpToken.sol";

contract Pool is InitializableERC20 {
    using SafeERC20 for IERC20Metadata;

    uint256 constant SECONDS_PER_YEAR = 31_536_000;
    uint256 constant SECONDS_TO_EXPIRY_FLOOR = 86_400;

    address public xToken; // Underlying token
    address public yToken; // Cap token

    uint256 public x; // Underlying token balance
    uint256 public y; // Cap token balance

    uint256 public a; // in units of 18**18
    uint256 public expiry; // block timestamp

    error Invalid();
    error XInTooLarge();
    error SlippageViolation();
    error DeadlineViolation();
    error PoolExpired();

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _upToken,
        uint256 _a,
        uint256 _k,
        uint256 _t,
        address to
    ) external initializer returns (address, address, uint256) {
        address _yToken = UpToken(_upToken).capToken();
        address _xToken = address(UpToken(_upToken).underlyingToken());

        (xToken, yToken) = (_xToken, _yToken);

        decimals = IERC20Metadata(_xToken).decimals();
        if (decimals != 18) {
            // @dev: currently only 18 decimals supported
            revert Invalid();
        }

        name = IERC20Metadata(_xToken).name();
        symbol = IERC20Metadata(_xToken).symbol();

        // @dev: pool cannot expire after upToken; using _t as parameter
        // allows to deterministically compute x0y0 in advance
        if (block.timestamp + _t > UpToken(_upToken).expiry()) {
            revert Invalid();
        }
        expiry = block.timestamp + _t;

        // @dev: currently only 50/50 initialization supported
        uint256 x0y0 = calcEquilibriumPoint(_a, _k, _t);
        (x, y) = (x0y0, x0y0);

        a = _a;

        // @dev: mint pool tokens 1:1
        _mint(to, x0y0);

        return (_xToken, _yToken, x0y0);
    }

    function swapGetYGivenXIn(
        address to,
        uint256 xIn,
        uint256 minYOut,
        uint256 deadline
    ) external returns (uint256) {
        (uint256 _x0, uint256 _y0, uint256 _a, uint256 _t) = (
            x,
            y,
            a,
            getSecondsToExpiry()
        );
        uint256 _k = calcK(_x0, _y0, _a, _t);
        uint256 yOut = calcYOutGivenXIn(_x0, xIn, _a, _k, _t);
        _swapCheck(yOut, minYOut, deadline, _t);
        x += xIn;
        y -= yOut;
        IERC20Metadata(xToken).safeTransferFrom(msg.sender, address(this), xIn);
        IERC20Metadata(yToken).safeTransfer(to, yOut);
        return yOut;
    }

    function swapGetXGivenYIn(
        address to,
        uint256 yIn,
        uint256 minXOut,
        uint256 deadline
    ) external returns (uint256) {
        (uint256 _x0, uint256 _y0, uint256 _a, uint256 _t) = (
            x,
            y,
            a,
            getSecondsToExpiry()
        );
        uint256 _k = calcK(_x0, _y0, _a, _t);
        uint256 xOut = calcXOutGivenYIn(_y0, yIn, _a, _k, _t);
        _swapCheck(xOut, minXOut, deadline, _t);
        x -= xOut;
        y += yIn;
        IERC20Metadata(xToken).safeTransfer(to, xOut);
        IERC20Metadata(yToken).safeTransferFrom(msg.sender, address(this), yIn);
        return xOut;
    }

    function addLiquidity() external returns (uint256, uint256) {
        // @dev: not supported yet
    }

    function removeLiquidity(
        address to,
        uint256 amount
    ) external returns (uint256, uint256) {
        // @dev: currently adding not supported yet, so simply return full amount
        uint256 _totalSupply = totalSupply();

        (address _xToken, address _yToken) = (xToken, yToken);
        uint256 xOut;
        uint256 yOut;
        if (amount == _totalSupply) {
            (xOut, yOut) = (
                (x * amount) / _totalSupply,
                (y * amount) / _totalSupply
            );
        } else {
            (xOut, yOut) = (
                IERC20Metadata(_xToken).balanceOf(address(this)),
                IERC20Metadata(_yToken).balanceOf(address(this))
            );
        }

        (uint256 xNew, uint256 yNew) = (x - xOut, y - yOut);
        (x, y) = (xNew, yNew);
        _burn(msg.sender, amount);
        IERC20Metadata(_xToken).transfer(to, xOut);
        IERC20Metadata(_yToken).transfer(to, yOut);
        return (xNew, yNew);
    }

    function getSecondsToExpiry()
        public
        view
        returns (uint256 _secondsToExpiry)
    {
        uint256 _expiry = expiry;
        if (_expiry > block.timestamp) {
            _secondsToExpiry = _expiry - block.timestamp >
                SECONDS_TO_EXPIRY_FLOOR
                ? _expiry - block.timestamp
                : SECONDS_TO_EXPIRY_FLOOR;
        } else {
            _secondsToExpiry = SECONDS_TO_EXPIRY_FLOOR;
        }
    }

    function getYOutGivenXIn(
        uint256 _xIn
    )
        public
        view
        returns (uint256, uint256, uint256, uint256, uint256, uint256)
    {
        (uint256 _x0, uint256 _y0, uint256 _a, uint256 _t) = (
            x,
            y,
            a,
            getSecondsToExpiry()
        );
        uint256 _k = calcK(_x0, _y0, _a, _t);
        uint256 yOut = calcYOutGivenXIn(_x0, _xIn, _a, _k, _t);
        return (yOut, _x0, _y0, _a, _k, _t);
    }

    function getXOutGivenYIn(
        uint256 _yIn
    )
        public
        view
        returns (uint256, uint256, uint256, uint256, uint256, uint256)
    {
        (uint256 _x0, uint256 _y0, uint256 _a, uint256 _t) = (
            x,
            y,
            a,
            getSecondsToExpiry()
        );
        uint256 _k = calcK(_x0, _y0, _a, _t);
        uint256 xOut = calcXOutGivenYIn(_y0, _yIn, _a, _k, _t);
        return (xOut, _x0, _y0, _a, _k, _t);
    }

    function calcYOutGivenXIn(
        uint256 _x0,
        uint256 _xIn,
        uint256 _a,
        uint256 _k,
        uint256 _t
    ) public pure returns (uint256) {
        uint256 xMax = calcXMax(_a, _k, _t);
        if (_xIn + _x0 >= xMax) {
            revert XInTooLarge();
        }
        uint256 y0 = calcY(_x0, _a, _k, _t);
        uint256 yNew = calcY(_xIn + _x0, _a, _k, _t);
        return y0 - yNew;
    }

    function calcXOutGivenYIn(
        uint256 _y0,
        uint256 _yIn,
        uint256 _a,
        uint256 _k,
        uint256 _t
    ) public pure returns (uint256) {
        uint256 x0 = calcX(_y0, _a, _k, _t);
        uint256 xNew = calcX(_y0 + _yIn, _a, _k, _t);
        return x0 - xNew;
    }

    function calcXMax(
        uint256 _a,
        uint256 _k,
        uint256 _t
    ) public pure returns (uint256) {
        // x_m = (1/2) * (sqrt(k) * sqrt(4 * a * sqrt(t) + k) + k)
        return
            (Math.sqrt(_k) *
                (
                    Math.sqrt(
                        Math.mulDiv(
                            4 * _a,
                            Math.sqrt(_t),
                            Math.sqrt(SECONDS_PER_YEAR)
                        ) + _k
                    )
                ) +
                _k) / 2;
    }

    function calcY(
        uint256 _x,
        uint256 _a,
        uint256 _k,
        uint256 _t
    ) public pure returns (uint256) {
        // y = (a * sqrt(t) * k) / x + k - x
        return
            Math.mulDiv(
                _a,
                Math.sqrt(_t) * _k,
                _x * Math.sqrt(SECONDS_PER_YEAR)
            ) +
            _k -
            _x;
    }

    function calcX(
        uint256 _y,
        uint256 _a,
        uint256 _k,
        uint256 _t
    ) public pure returns (uint256) {
        // x = (1/2) * (sqrt(4 * a * k * sqrt(t) + k**2 + y**2 - 2 * k * y) + k - y)
        return
            (Math.sqrt(
                Math.mulDiv(
                    4 * _a * _k,
                    Math.sqrt(_t),
                    Math.sqrt(SECONDS_PER_YEAR)
                ) +
                    _k ** 2 +
                    _y ** 2 -
                    2 *
                    _k *
                    _y
            ) +
                _k -
                _y) / 2;
    }

    function calcK(
        uint256 _x,
        uint256 _y,
        uint256 _a,
        uint256 _t
    ) public pure returns (uint256) {
        // k = x * ((x + y) / (a * sqrt(t) + x))
        return
            Math.mulDiv(
                _x * Math.sqrt(SECONDS_PER_YEAR),
                _x + _y,
                _a * Math.sqrt(_t) + _x * Math.sqrt(SECONDS_PER_YEAR)
            );
    }

    function calcEquilibriumPoint(
        uint256 _a,
        uint256 _k,
        uint256 _t
    ) public pure returns (uint256) {
        // x_e = (1/4) * (sqrt(k) * sqrt(8 * a * sqrt(t) + k) + k)
        return
            (Math.sqrt(_k) *
                (
                    Math.sqrt(
                        (8 * _a * Math.sqrt(_t)) /
                            Math.sqrt(SECONDS_PER_YEAR) +
                            _k
                    )
                ) +
                _k) / 4;
    }

    function calcYNew(
        uint256 xAdd,
        uint256 _x0,
        uint256 _a,
        uint256 _k,
        uint256 _t
    ) public pure returns (uint256) {
        // y_new = (a * sqrt(t) * k * beta**2) / x_new + k * beta**2 - x_new
        // where
        // x_new = xAdd + x_old
        // and
        // beta = x_new / x_old
        // -----------------------------------------------------------------
        // The derivative at this 'new point' is
        // y'_new = -(a * beta**2 * k * sqrt(t)) / (x_new**2) - 1
        // and is equal to derivative at 'old point'
        // y'_old = -(a * k * sqrt(t)) / (x_old**2) - 1
        return (Math.mulDiv(
            _a * Math.sqrt(_t) * _k,
            (xAdd + _x0) ** 2,
            _x0 ** 2 * (_x0 + xAdd) * Math.sqrt(SECONDS_PER_YEAR)
        ) +
            Math.mulDiv(_k, (xAdd + _x0) ** 2, _x0 ** 2) -
            (_x0 + xAdd));
    }

    function _swapCheck(
        uint256 out,
        uint256 minOut,
        uint256 deadline,
        uint256 t
    ) internal view {
        if (out < minOut) {
            revert SlippageViolation();
        }
        if (block.timestamp >= deadline) {
            revert DeadlineViolation();
        }
        if (t <= SECONDS_TO_EXPIRY_FLOOR) {
            revert PoolExpired();
        }
    }
}

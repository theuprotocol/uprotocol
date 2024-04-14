// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {InitializableERC20} from "./InitializableERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract CapToken is InitializableERC20 {
    address public upToken;

    error Unauthorized();

    function initialize(address _upToken) external initializer {
        decimals = IERC20Metadata(_upToken).decimals();
        upToken = _upToken;
    }

    function mint(address to, uint value) external {
        if (msg.sender != upToken) {
            revert Unauthorized();
        }
        _mint(to, value);
    }

    function burn(address from, uint value) external {
        if (msg.sender != upToken) {
            revert Unauthorized();
        }
        _burn(from, value);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {InitializableERC20} from "./InitializableERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract BToken is InitializableERC20 {
    address public uToken;

    error Unauthorized();

    function initialize(address _uToken) external initializer {
        decimals = IERC20Metadata(_uToken).decimals();
        uToken = _uToken;
    }

    function mint(address to, uint value) external {
        if (msg.sender != uToken) {
            revert Unauthorized();
        }
        _mint(to, value);
    }

    function burn(address from, uint value) external {
        if (msg.sender != uToken) {
            revert Unauthorized();
        }
        _burn(from, value);
    }
}

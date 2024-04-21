// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {InitializableERC20} from "../utils/InitializableERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {UpToken} from "./UpToken.sol";

contract CapToken is InitializableERC20 {
    using SafeERC20 for IERC20Metadata;

    address public upToken;

    error Unauthorized();
    error PreExpiry();
    error NothingToClaim();

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

    function convert(address to) external {
        if (block.timestamp <= UpToken(upToken).expiry()) {
            revert PreExpiry();
        }
        (
            uint256 convertableAmount,
            uint256 unexercisedProRata,
            uint256 accBal,
            address settlementToken
        ) = convertable(msg.sender);
        if (convertableAmount == 0 || accBal == 0) {
            revert NothingToClaim();
        }
        _burn(msg.sender, accBal);
        IERC20Metadata(settlementToken).safeTransfer(to, convertableAmount);
        if (unexercisedProRata > 0) {
            IERC20Metadata(UpToken(upToken).underlyingToken()).safeTransferFrom(
                upToken,
                to,
                unexercisedProRata
            );
        }
    }

    function convertable(
        address account
    )
        public
        view
        returns (
            uint256 convertableAmount,
            uint256 unexercisedProRata,
            uint256 accBal,
            address settlementToken
        )
    {
        uint256 _totalSupply = totalSupply();
        accBal = balanceOf(account);
        settlementToken = UpToken(upToken).settlementToken();
        uint256 unexercised = UpToken(upToken).totalUnexercised();
        if (block.timestamp > UpToken(upToken).expiry()) {
            uint256 settlementBal = IERC20Metadata(settlementToken).balanceOf(
                address(this)
            );
            if (accBal == _totalSupply) {
                convertableAmount = settlementBal;
                unexercisedProRata = unexercised;
            } else {
                convertableAmount = (accBal * settlementBal) / _totalSupply;
                unexercised = (accBal * unexercised) / _totalSupply;
            }
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {CapToken} from "../tokenization/CapToken.sol";
import {UpToken} from "../tokenization/UpToken.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

contract TokenFactory {
    using SafeERC20 for IERC20Metadata;

    address public immutable capTokenImplementation;
    address public immutable upTokenImplementation;
    mapping(address => mapping(address => address[])) internal upTokens;
    mapping(address => mapping(address => address[])) internal capTokens;

    error InvalidRange();
    error OutOfBounds();

    constructor(
        address _capTokenImplementation,
        address _upTokenImplementation
    ) {
        capTokenImplementation = _capTokenImplementation;
        upTokenImplementation = _upTokenImplementation;
    }

    function create(
        address _underlyingToken,
        address _settlementToken,
        uint256 _strike,
        uint256 _expiry
    ) external returns (address, address) {
        address newCapToken = Clones.cloneDeterministic(
            capTokenImplementation,
            keccak256(
                abi.encode(_underlyingToken, _settlementToken, _strike, _expiry)
            )
        );

        address newUpToken = Clones.cloneDeterministic(
            upTokenImplementation,
            keccak256(
                abi.encode(_underlyingToken, _settlementToken, _strike, _expiry)
            )
        );
        upTokens[_underlyingToken][_settlementToken].push(newUpToken);
        capTokens[_underlyingToken][_settlementToken].push(newCapToken);

        {
            string memory name = IERC20Metadata(_underlyingToken).name();
            string memory symbol = IERC20Metadata(_underlyingToken).symbol();
            CapToken(newCapToken).initialize(
                string(abi.encodePacked("C-", name)),
                string(abi.encodePacked("c", symbol)),
                IERC20Metadata(_underlyingToken).decimals(),
                newUpToken
            );
            UpToken(newUpToken).initialize(
                string(abi.encodePacked("U-", name)),
                string(abi.encodePacked("u", symbol)),
                IERC20Metadata(_underlyingToken).decimals(),
                _underlyingToken,
                _settlementToken,
                newCapToken,
                _strike,
                _expiry
            );
        }

        return (newCapToken, newUpToken);
    }

    function tokens(
        address underlying,
        address settlement,
        uint256 from,
        uint256 numElements
    ) external view returns (address[] memory, address[] memory) {
        uint256 length = capTokens[underlying][settlement].length;
        if (numElements == 0) {
            revert InvalidRange();
        }
        if (from + numElements > length + 1) {
            revert OutOfBounds();
        }
        address[] memory _upTokens = new address[](numElements);
        address[] memory _capTokens = new address[](numElements);
        for (uint256 i = 0; i < numElements; i++) {
            _upTokens[i] = upTokens[underlying][settlement][from + i];
            _capTokens[i] = capTokens[underlying][settlement][from + i];
        }
        return (_upTokens, _capTokens);
    }
}

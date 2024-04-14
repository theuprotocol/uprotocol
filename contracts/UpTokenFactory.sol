// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {CapToken} from "./CapToken.sol";
import {UpToken} from "./UpToken.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

contract UpTokenFactory {
    using SafeERC20 for IERC20Metadata;

    address public immutable capTokenImplementation;
    address public immutable upTokenImplementation;
    mapping(IERC20Metadata => mapping(IERC20Metadata => address[]))
        internal upTokens;
    mapping(IERC20Metadata => mapping(IERC20Metadata => address[]))
        internal capTokens;

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
        IERC20Metadata _underlyingToken,
        IERC20Metadata _settlementToken,
        uint256 _strike,
        uint256 _expiry,
        address to,
        uint256 amount
    ) external returns (address, address) {
        address _capTokenImplementation = capTokenImplementation;
        address _upTokenImplementation = upTokenImplementation;

        address newBToken = Clones.cloneDeterministic(
            _capTokenImplementation,
            keccak256(
                abi.encode(
                    _capTokenImplementation,
                    _underlyingToken,
                    _settlementToken,
                    _strike,
                    _expiry
                )
            )
        );

        address newUToken = Clones.cloneDeterministic(
            upTokenImplementation,
            keccak256(
                abi.encode(
                    _upTokenImplementation,
                    _underlyingToken,
                    _settlementToken,
                    _strike,
                    _expiry
                )
            )
        );
        upTokens[_underlyingToken][_settlementToken].push(newUToken);
        capTokens[_underlyingToken][_settlementToken].push(newBToken);

        UpToken(newUToken).initialize(
            _underlyingToken,
            _settlementToken,
            newBToken,
            _strike,
            _expiry,
            to,
            amount
        );
        CapToken(newBToken).initialize(newBToken);

        return (newBToken, newUToken);
    }

    function getCapTokens(
        IERC20Metadata underlying,
        IERC20Metadata settlement,
        uint256 from,
        uint256 numElements
    ) external view returns (address[] memory) {
        address[] memory allCapTokens = capTokens[underlying][settlement];
        return _getTokens(allCapTokens, from, numElements);
    }

    function getUpTokens(
        IERC20Metadata underlying,
        IERC20Metadata settlement,
        uint256 from,
        uint256 numElements
    ) external view returns (address[] memory) {
        address[] memory allUpTokens = upTokens[underlying][settlement];
        return _getTokens(allUpTokens, from, numElements);
    }

    function _getTokens(
        address[] memory allTokens,
        uint256 from,
        uint256 numElements
    ) internal pure returns (address[] memory) {
        if (numElements == 0) {
            revert InvalidRange();
        }
        uint256 length = allTokens.length;
        if (from + numElements > length + 1) {
            revert OutOfBounds();
        }
        address[] memory selectedTokens = new address[](numElements);
        for (uint256 i = 0; i < numElements; i++) {
            selectedTokens[i] = allTokens[from + i];
        }
        return selectedTokens;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {UToken} from "./UToken.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

contract UTokenFactory {
    using SafeERC20 for IERC20Metadata;

    address public immutable bTokenImplementation;
    address public immutable uTokenImplementation;
    mapping(IERC20Metadata => mapping(IERC20Metadata => address[]))
        public uTokens;
    mapping(IERC20Metadata => mapping(IERC20Metadata => address[]))
        public bTokens;

    constructor(address _bTokenImplementation, address _uTokenImplementation) {
        bTokenImplementation = _bTokenImplementation;
        uTokenImplementation = _uTokenImplementation;
    }

    function tokenizeUnderlying(
        IERC20Metadata _underlyingToken,
        IERC20Metadata _settlementToken,
        uint256 _strike,
        uint256 _expiry
    ) external returns (address, address) {
        address _bTokenImplementation = bTokenImplementation;
        address _uTokenImplementation = uTokenImplementation;

        address newBToken = Clones.cloneDeterministic(
            _bTokenImplementation,
            keccak256(
                abi.encode(
                    _bTokenImplementation,
                    _underlyingToken,
                    _settlementToken,
                    _strike,
                    _expiry
                )
            )
        );
        address newUToken = Clones.cloneDeterministic(
            uTokenImplementation,
            keccak256(
                abi.encode(
                    _uTokenImplementation,
                    _underlyingToken,
                    _settlementToken,
                    _strike,
                    _expiry
                )
            )
        );
        uTokens[_underlyingToken][_settlementToken].push(newUToken);
        bTokens[_underlyingToken][_settlementToken].push(newBToken);

        UToken(newUToken).initialize(
            _underlyingToken,
            _settlementToken,
            IERC20Metadata(newBToken),
            _strike,
            _expiry
        );
        return (newBToken, newUToken);
    }
}

// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

import "../../external/Valerium2771Context.sol";

/**
 * @title TargetChecker - A contract that contains the required dependencies from "isTrustedForwarder" function.
 * @author Anoy Roy Chowdhury - <anoyroyc3545@gmail.com>
 * @notice This contract is specifically designed to be used with the Valerium Wallet. Some function may not work as expected if used with other wallets.
 */

library TargetChecker {

    /**
     * Checks if the forwarder is trusted by the target
     * @param target address of the target contract
     */
    function _isTrustedByTarget(address target) internal view returns (bool) {
        bytes memory encodedParams = abi.encodeCall(Valerium2771Context.isTrustedForwarder, (address(this)));

        bool success;
        uint256 returnSize;
        uint256 returnValue;
        assembly {
            success := staticcall(gas(), target, add(encodedParams, 0x20), mload(encodedParams), 0, 0x20)
            returnSize := returndatasize()
            returnValue := mload(0)
        }

        return success && returnSize >= 0x20 && returnValue > 0;
    }

    /**
     * Checks if the gas forwarded is sufficient
     * @param gasLeft gas left after the forwarding
     * @param requestGas gas requested for the forwarding
     * @dev To avoid insufficient gas griefing attacks, as referenced in https://ronan.eth.limo/blog/ethereum-gas-dangers/
     */
    function _checkForwardedGas(uint256 gasLeft, uint256 requestGas) internal pure {
        if (gasLeft < requestGas / 63) {
            assembly {
                invalid()
            }
        }
    }
}
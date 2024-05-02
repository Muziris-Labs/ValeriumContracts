// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

/**
 * @title FactoryLogManager - This contract is used to manage the errors and logs for the Valerium protocol.
 * @dev This contract is a base contract for managing the errors and logs for the Valerium protocol.
 * @author Anoy Roy Chowdhury - <anoyroyc3545@gmail.com>
 */

abstract contract FactoryLogManager{
    bytes4 internal constant MISMATCH_VALUE = bytes4(keccak256("Valerium: mismatched value"));
    bytes4 internal constant EXPIRED_REQUEST = bytes4(keccak256("Valerium: expired request"));
    bytes4 internal constant UNTRUSTFUL_TARGET = bytes4(keccak256("Valerium: untrustful target"));
    bytes4 internal constant INVALID_SIGNER = bytes4(keccak256("Valerium: invalid signer"));
    bytes4 internal constant DEPLOYMENT_FAILED = bytes4(keccak256("Valerium: deployment failed"));
    bytes4 internal constant INSUFFICIENT_BALANCE = bytes4(keccak256("Valerium: insufficient balance"));

    bytes4 internal constant DEPLOYMENT_SUCCESSFUL = bytes4(keccak256("Valerium: deployment successful"));
}
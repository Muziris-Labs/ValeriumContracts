// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

/**
 * @title LogManager - This contract is used to manage the errors and logs for the Valerium protocol.
 * @dev This contract is a base contract for managing the errors and logs for the Valerium protocol.
 * @author Anoy Roy Chowdhury - <anoyroyc3545@gmail.com>
 */

abstract contract LogManager{
    // Invalid Proof Error
    bytes4 internal constant INVALID_PROOF = bytes4(keccak256("Valerium: invalid proof"));

    // Invalid Balance Error
    bytes4 internal constant INSUFFICIENT_BALANCE = bytes4(keccak256("Valerium: insufficient balance"));

    // Unexpected Error
    bytes4 internal constant UNEXPECTED_ERROR = bytes4(keccak256("Valerium: unexpected error"));

    // Error Transfering
    bytes4 internal constant TRANSFER_FAILED = bytes4(keccak256("Valerium: Gas Transfer failed"));

    // Execution Successful
    bytes4 internal constant EXECUTION_SUCCESSFUL = bytes4(keccak256("Valerium: execution successful"));

    // Recovery Successful
    bytes4 internal constant RECOVERY_SUCCESSFUL = bytes4(keccak256("Valerium: recovery successful"));

    // Change Successful
    bytes4 internal constant CHANGE_SUCCESSFUL = bytes4(keccak256("Valerium: change successful"));
}
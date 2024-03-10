// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

/**
 * @title DataManager - A contract that contains all the struct and typehashes for the ValeriumForwarder contract.
 * @notice This contract is specifically designed to be used with the Valerium Wallet. Some function may not work as expected if used with other wallets.
 * @author Anoy Roy Chwodhury - <anoyroyc3545@gmail.com>
 */

contract DataManager {
    // struct of forwarded message for "executeWithForwarder" function
    struct ForwardExecuteData {
        address from;
        address recipient;
        uint48 deadline;
        uint256 gas;
        bytes proof;
        address to;
        uint256 value;
        bytes data;
        bytes signature;
    }

    // typehash of ForwardExecuteData
    bytes32 internal constant FORWARD_EXECUTE_TYPEHASH = keccak256(
        "ForwardExecute(address from,address recipient,uint256 deadline,uint256 nonce,uint256 gas,bytes proof,address to,uint256 value,bytes data)"
    );

    // struct of forwarded message for "executeBatchWithForwarder" function
    struct ForwardExecuteBatchData {
        address from;
        address recipient;
        uint48 deadline;
        uint256 gas;
        bytes proof;
        address[] to;
        uint256[] value;
        bytes[] data;
        bytes signature;
    }

    // typehash of ForwardExecuteBatchData
    bytes32 internal constant FORWARD_EXECUTE_BATCH_TYPEHASH = keccak256(
        "ForwardExecuteBatch(address from,address recipient,uint256 deadline,uint256 nonce,uint256 gas,bytes proof,bytes32 to,bytes32 value,bytes32 data)"
    );

    // struct of forwarded message for "executeRecoveryWithForwarder" function
    struct ForwardExecuteRecoveryData {
        address from;
        address recipient;
        uint48 deadline;
        uint256 gas;
        bytes proof;
        bytes32 newTxHash;
        address newTxVerifier;
        bytes publicStorage;
        bytes signature;
    }

    // typehash of ForwardExecuteRecoveryData
    bytes32 internal constant FORWARD_EXECUTE_RECOVERY_TYPEHASH = keccak256(
        "ForwardExecuteRecovery(address from,address recipient,uint256 deadline,uint256 nonce,uint256 gas,bytes proof,bytes32 newTxHash,address newTxVerifier,bytes publicStorage)"
    );

    // struct of forwarded message for "changeRecoveryWithForwarder" function
    struct ForwardChangeRecoveryData {
        address from;
        address recipient;
        uint48 deadline;
        uint256 gas;
        bytes proof;
        bytes32 newRecoveryHash;
        address newRecoveryVerifier;
        bytes publicStorage;
        bytes signature;
    }

    // typehash of ForwardChangeRecoveryData
    bytes32 internal constant FORWARD_CHANGE_RECOVERY_TYPEHASH = keccak256(
        "ForwardChangeRecovery(address from,address recipient,uint256 deadline,uint256 nonce,uint256 gas,bytes proof,bytes32 newRecoveryHash,address newRecoveryVerifier,bytes publicStorage)"
    );
}
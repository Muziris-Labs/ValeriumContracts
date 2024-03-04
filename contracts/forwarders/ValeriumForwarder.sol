// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/utils/Nonces.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../external/ERC2771Context.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../Valerium.sol";

/**
 * @title ValeriumForwarder - A contract that forwards transactions to a target contract.
 * @notice This contract is specifically designed to be used with the Valerium Wallet. Some function may not work as expected if used with other wallets.
 * @author Anoy Roy Chwodhury - <anoyroyc3545@gmail.com>
 */

contract ValeriumForwarder is EIP712, Nonces {
    using ECDSA for bytes32;

    // Initializing EIP-712 Domain Separator
    constructor(string memory name, string memory version) EIP712(name, version) {}

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

    bytes32 private constant FORWARD_EXECUTE_TYPEHASH = keccak256(
        "ForwardExecute(address from,address recipient,uint256 deadline,uint256 nonce,uint256 gas,bytes proof,address to,uint256 value,bytes data)"
    );

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

    bytes32 private constant FORWARD_EXECUTE_BATCH_TYPEHASH = keccak256(
        "ForwardExecuteBatch(address from,address recipient,uint256 deadline,uint256 nonce,uint256 gas,bytes proof,address[] to,uint256[] value,bytes[] data)"
    );

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

    bytes32 private constant FORWARD_EXECUTE_RECOVERY_TYPEHASH = keccak256(
        "ForwardExecuteRecovery(address from,address recipient,uint256 deadline,uint256 nonce,uint256 gas,bytes proof,bytes32 newTxHash,address newTxVerifier,bytes publicStorage)"
    );

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

    bytes32 private constant FORWARD_CHANGE_RECOVERY_TYPEHASH = keccak256(
        "ForwardChangeRecovery(address from,address recipient,uint256 deadline,uint256 nonce,uint256 gas,bytes proof,bytes32 newRecoveryHash,address newRecoveryVerifier,bytes publicStorage)"
    );

    function _validate(
        ForwardExecuteData calldata request
    ) internal view virtual returns (bool isTrustedForwarder, bool active, bool signerMatch, address signer) {
        (bool isValid, address recovered) = _recoverForwardExecuteSigner(request);

        return (
            _isTrustedByTarget(request.to),
            request.deadline >= block.timestamp,
            isValid && recovered == request.from,
            recovered
        );
    }

    function _recoverForwardExecuteSigner(
        ForwardExecuteData calldata request
    ) internal view virtual returns (bool, address) {
        (address recovered, ECDSA.RecoverError err, ) = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    FORWARD_EXECUTE_TYPEHASH,
                    request.from,
                    request.recipient,
                    request.deadline,
                    nonces(request.from),
                    request.gas,
                    request.proof,
                    request.to,
                    request.value,
                    keccak256(request.data)
                )
            )
        ).tryRecover(request.signature);

        return (err == ECDSA.RecoverError.NoError, recovered);
    }

    error ERC2771ForwarderInvalidSigner(address signer, address from);

    function execute(ForwardExecuteData calldata request, uint256 gasPrice, uint256 baseGas, uint256 estimatedFees ) public payable virtual {
        require(msg.value == 0, "ValeriumForwarder: invalid msg.value");

        if (!_execute(request, gasPrice, baseGas, estimatedFees, true)) {
            revert ERC2771ForwarderInvalidSigner(request.from, msg.sender);
        }
    }

    error ERC2771ForwarderMismatchedValue(uint256 requestedValue, uint256 msgValue);

    error ERC2771ForwarderExpiredRequest(uint48 deadline);

    error ERC2771UntrustfulTarget(address target, address forwarder);


    function _execute(
        ForwardExecuteData calldata request,
        uint256 gasPrice,
        uint256 baseGas,
        uint256 estimatedFees,
        bool requireValidRequest
    ) internal virtual returns (bool success) {
        (bool isTrustedForwarder, bool active, bool signerMatch, address signer) = _validate(request);

        // Need to explicitly specify if a revert is required since non-reverting is default for
        // batches and reversion is opt-in since it could be useful in some scenarios
        if (requireValidRequest) {
            if (!isTrustedForwarder) {
                revert ERC2771UntrustfulTarget(request.to, address(this));
            }

            if (!active) {
                revert ERC2771ForwarderExpiredRequest(request.deadline);
            }

            if (!signerMatch) {
                revert ERC2771ForwarderInvalidSigner(signer, request.from);
            }
        }

        // Ignore an invalid request because requireValidRequest = false
        if (isTrustedForwarder && signerMatch && active) {
            // Nonce should be used before the call to prevent reusing by reentrancy
            uint256 currentNonce = _useNonce(signer);

            bytes memory data = abi.encodePacked(request.data, request.from);

            uint256 gasLeft;

            success = Valerium(request.recipient).executeTxWithForwarder(
                request.proof,
                request.to,
                request.value,
                request.data,
                gasPrice,
                baseGas,
                estimatedFees
            );

            _checkForwardedGas(gasLeft, request);
        }
    }

    function _isTrustedByTarget(address target) private view returns (bool) {
        bytes memory encodedParams = abi.encodeCall(ERC2771Context.isTrustedForwarder, (address(this)));

        bool success;
        uint256 returnSize;
        uint256 returnValue;
        /// @solidity memory-safe-assembly
        assembly {
            // Perform the staticcal and save the result in the scratch space.
            // | Location  | Content  | Content (Hex)                                                      |
            // |-----------|----------|--------------------------------------------------------------------|
            // |           |          |                                                           result ↓ |
            // | 0x00:0x1F | selector | 0x0000000000000000000000000000000000000000000000000000000000000001 |
            success := staticcall(gas(), target, add(encodedParams, 0x20), mload(encodedParams), 0, 0x20)
            returnSize := returndatasize()
            returnValue := mload(0)
        }

        return success && returnSize >= 0x20 && returnValue > 0;
    }

    function _checkForwardedGas(uint256 gasLeft, ForwardExecuteData calldata request) private pure {
        // To avoid insufficient gas griefing attacks, as referenced in https://ronan.eth.limo/blog/ethereum-gas-dangers/
        //
        // A malicious relayer can attempt to shrink the gas forwarded so that the underlying call reverts out-of-gas
        // but the forwarding itself still succeeds. In order to make sure that the subcall received sufficient gas,
        // we will inspect gasleft() after the forwarding.
        //
        // Let X be the gas available before the subcall, such that the subcall gets at most X * 63 / 64.
        // We can't know X after CALL dynamic costs, but we want it to be such that X * 63 / 64 >= req.gas.
        // Let Y be the gas used in the subcall. gasleft() measured immediately after the subcall will be gasleft() = X - Y.
        // If the subcall ran out of gas, then Y = X * 63 / 64 and gasleft() = X - Y = X / 64.
        // Under this assumption req.gas / 63 > gasleft() is true is true if and only if
        // req.gas / 63 > X / 64, or equivalently req.gas > X * 63 / 64.
        // This means that if the subcall runs out of gas we are able to detect that insufficient gas was passed.
        //
        // We will now also see that req.gas / 63 > gasleft() implies that req.gas >= X * 63 / 64.
        // The contract guarantees Y <= req.gas, thus gasleft() = X - Y >= X - req.gas.
        // -    req.gas / 63 > gasleft()
        // -    req.gas / 63 >= X - req.gas
        // -    req.gas >= X * 63 / 64
        // In other words if req.gas < X * 63 / 64 then req.gas / 63 <= gasleft(), thus if the relayer behaves honestly
        // the forwarding does not revert.
        if (gasLeft < request.gas / 63) {
            // We explicitly trigger invalid opcode to consume all gas and bubble-up the effects, since
            // neither revert or assert consume all gas since Solidity 0.8.20
            // https://docs.soliditylang.org/en/v0.8.20/control-structures.html#panic-via-assert-and-error-via-require
            /// @solidity memory-safe-assembly
            assembly {
                invalid()
            }
        }
    }
}


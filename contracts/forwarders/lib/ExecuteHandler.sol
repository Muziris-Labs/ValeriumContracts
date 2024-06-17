// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/Nonces.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../../external/Valerium2771Context.sol";
import "./ForwarderLogManager.sol";
import "./TargetChecker.sol";
import "../interfaces/IValerium.sol";
import "./DataManager.sol";

/**
 * @title ExecuteHandler - A contract that contains the required dependencies from "executeTxWithForwarder" function.
 * @author Anoy Roy Chowdhury - <anoyroyc3545@gmail.com>
 * @notice This contract is specifically designed to be used with the Valerium Wallet. Some function may not work as expected if used with other wallets.
 */

abstract contract ExecuteHandler is EIP712, Nonces, DataManager {
    using ECDSA for bytes32;

    // Initializing the EIP712 Domain Separator
    constructor(
        string memory name,
        string memory version
    ) EIP712(name, version) {}

    /**
     * Executes the "executeTxWithForwarder" function of the Valerium contract.
     * @param request ForwardExecuteData struct
     * @param token The address of the token
     * @param gasPrice Estimated Gas Price for the transaction
     * @param baseGas Base Gas Fee for the transaction
     * @param estimatedFees estimated
     * @param requireValidRequest If true, the function will revert if the request is invalid
     */
    function _execute(
        ForwardExecuteData calldata request,
        address token,
        uint256 gasPrice,
        uint256 baseGas,
        uint256 estimatedFees,
        bool requireValidRequest
    ) internal virtual returns (bytes4 macicValue) {
        {
            (
                bool isTrustedForwarder,
                bool active,
                bool signerMatch,
                address signer
            ) = _validate(request);

            // Need to explicitly specify if a revert is required since non-reverting is default for
            // batches and reversion is opt-in since it could be useful in some scenarios
            if (requireValidRequest) {
                if (!isTrustedForwarder) {
                    return ForwarderLogManager.UNTRUSTFUL_TARGET;
                }

                if (!active) {
                    return ForwarderLogManager.EXPIRED_REQUEST;
                }

                if (!signerMatch) {
                    return ForwarderLogManager.INVALID_SIGNER;
                }
            }

            // Ignore an invalid request because requireValidRequest = false
            if (!isTrustedForwarder || !active || !signerMatch) {
                return ForwarderLogManager.EXECUTION_FAILED;
            }

            // Nonce should be used before the call to prevent reusing by reentrancy
            _useNonce(signer);
        }

        // Encode the parameters for optimized gas usage
        bytes memory encodedParams = encodeExecuteParams(
            request,
            token,
            gasPrice,
            baseGas,
            estimatedFees
        );

        (bool success, bytes memory result) = request.recipient.call{
            gas: request.gas
        }(encodedParams);

        TargetChecker._checkForwardedGas(gasleft(), request.gas);

        if (!success) {
            return ForwarderLogManager.EXECUTION_FAILED;
        }

        return abi.decode(result, (bytes4));
    }

    /**
     * Executes the "executeBatchTxWithForwarder" function of the Valerium contract.
     * @param request ForwardExecuteBatchData struct
     * @param token The address of the token
     * @param gasPrice Estimated Gas Price for the transaction
     * @param baseGas Base Gas Fee for the transaction
     * @param estimatedFees estimated
     * @param requireValidRequest If true, the function will revert if the request is invalid
     */
    function _executeBatch(
        ForwardExecuteBatchData calldata request,
        address token,
        uint256 gasPrice,
        uint256 baseGas,
        uint256 estimatedFees,
        bool requireValidRequest
    ) internal virtual returns (bytes4 magicValue) {
        (
            bool isTrustedForwarder,
            bool active,
            bool signerMatch,
            address signer
        ) = _validate(request);

        // Need to explicitly specify if a revert is required since non-reverting is default for
        // batches and reversion is opt-in since it could be useful in some scenarios
        if (requireValidRequest) {
            if (!isTrustedForwarder) {
                return ForwarderLogManager.UNTRUSTFUL_TARGET;
            }

            if (!active) {
                return ForwarderLogManager.EXPIRED_REQUEST;
            }

            if (!signerMatch) {
                return ForwarderLogManager.INVALID_SIGNER;
            }
        }

        // Ignore an invalid request because requireValidRequest = false
        if (!isTrustedForwarder || !active || !signerMatch) {
            return ForwarderLogManager.EXECUTION_FAILED;
        }

        // Nonce should be used before the call to prevent reusing by reentrancy
        _useNonce(signer);

        // Encode the parameters for optimized gas usage
        bytes memory encodedParams = encodeExecuteBatchParams(
            request,
            token,
            gasPrice,
            baseGas,
            estimatedFees
        );

        (bool success, bytes memory result) = request.recipient.call{
            gas: request.gas
        }(encodedParams);

        TargetChecker._checkForwardedGas(gasleft(), request.gas);

        if (!success) {
            return ForwarderLogManager.EXECUTION_FAILED;
        }

        return abi.decode(result, (bytes4));
    }

    /**
     * Executes the "executeRecoveryWithForwarder" function of the Valerium contract.
     * @param request ForwardExecuteRecoveryhData struct
     * @param token The address of the token
     * @param gasPrice Estimated Gas Price for the transaction
     * @param baseGas Base Gas Fee for the transaction
     * @param estimatedFees estimated
     * @param requireValidRequest If true, the function will revert if the request is invalid
     */
    function _executeRecovery(
        ForwardExecuteRecoveryData calldata request,
        address token,
        uint256 gasPrice,
        uint256 baseGas,
        uint256 estimatedFees,
        bool requireValidRequest
    ) internal virtual returns (bytes4 magicValue) {
        {
            (
                bool isTrustedForwarder,
                bool active,
                bool signerMatch,
                address signer
            ) = _validate(request);

            // Need to explicitly specify if a revert is required since non-reverting is default for
            // batches and reversion is opt-in since it could be useful in some scenarios
            if (requireValidRequest) {
                if (!isTrustedForwarder) {
                    return ForwarderLogManager.UNTRUSTFUL_TARGET;
                }

                if (!active) {
                    return ForwarderLogManager.EXPIRED_REQUEST;
                }

                if (!signerMatch) {
                    return ForwarderLogManager.INVALID_SIGNER;
                }
            }

            // Ignore an invalid request because requireValidRequest = false
            if (!isTrustedForwarder || !active || !signerMatch) {
                return ForwarderLogManager.EXECUTION_FAILED;
            }

            // Nonce should be used before the call to prevent reusing by reentrancy
            _useNonce(signer);
        }

        // Encode the parameters for more efficient gas usage
        bytes memory encodedParams = encodeExecuteRecoveryParams(
            request,
            token,
            gasPrice,
            baseGas,
            estimatedFees
        );

        (bool success, bytes memory result) = request.recipient.call{
            gas: request.gas
        }(encodedParams);

        TargetChecker._checkForwardedGas(gasleft(), request.gas);

        if (!success) {
            return ForwarderLogManager.EXECUTION_FAILED;
        }

        return abi.decode(result, (bytes4));
    }

    /**
     * Executes the "changeRecoveryWithForwarder" function of the Valerium contract.
     * @param request ForwardChangeRecoveryData struct
     * @param token The address of the token
     * @param gasPrice Estimated Gas Price for the transaction
     * @param baseGas Base Gas Fee for the transaction
     * @param estimatedFees estimated
     * @param requireValidRequest If true, the function will revert if the request is invalid
     */
    function _changeRecovery(
        ForwardChangeRecoveryData calldata request,
        address token,
        uint256 gasPrice,
        uint256 baseGas,
        uint256 estimatedFees,
        bool requireValidRequest
    ) internal virtual returns (bytes4 magicValue) {
        {
            (
                bool isTrustedForwarder,
                bool active,
                bool signerMatch,
                address signer
            ) = _validate(request);

            // Need to explicitly specify if a revert is required since non-reverting is default for
            // batches and reversion is opt-in since it could be useful in some scenarios
            if (requireValidRequest) {
                if (!isTrustedForwarder) {
                    return ForwarderLogManager.UNTRUSTFUL_TARGET;
                }

                if (!active) {
                    return ForwarderLogManager.EXPIRED_REQUEST;
                }

                if (!signerMatch) {
                    return ForwarderLogManager.INVALID_SIGNER;
                }
            }

            // Ignore an invalid request because requireValidRequest = false
            if (!isTrustedForwarder || !active || !signerMatch) {
                return ForwarderLogManager.EXECUTION_FAILED;
            }

            // Nonce should be used before the call to prevent reusing by reentrancy
            _useNonce(signer);
        }

        // Encode the parameters for more efficient gas usage
        bytes memory encodedParams = encodeChangeRecoveryParams(
            request,
            token,
            gasPrice,
            baseGas,
            estimatedFees
        );

        (bool success, bytes memory result) = request.recipient.call{
            gas: request.gas
        }(encodedParams);

        TargetChecker._checkForwardedGas(gasleft(), request.gas);

        if (!success) {
            return ForwarderLogManager.EXECUTION_FAILED;
        }

        return abi.decode(result, (bytes4));
    }

    /**
     * Encodes the parameters for the "executeTxWithForwarder" function of the Valerium contract for avoiding stack too deep error
     * @param request ForwardExecuteData struct
     * @param token The address of the token
     * @param gasPrice Estimated Gas Price for the transaction
     * @param baseGas Base Gas Fee for the transaction
     * @param estimatedFees estimated
     */
    function encodeExecuteParams(
        ForwardExecuteData calldata request,
        address token,
        uint256 gasPrice,
        uint256 baseGas,
        uint256 estimatedFees
    ) internal pure returns (bytes memory) {
        bytes4 functionSignature = IValerium.executeTxWithForwarder.selector;
        return
            abi.encodeWithSelector(
                functionSignature,
                request.proof,
                request.from,
                request.to,
                request.value,
                request.data,
                token,
                gasPrice,
                baseGas,
                estimatedFees
            );
    }

    /**
     * Validates the request by checking if the forwarder is trusted by the target, the request is active and the signer is valid
     * @param request ForwardExecuteData struct
     * @return isTrustedForwarder If the forwarder is trusted by the target, returns true
     * @return active Checks the deadline of the request and returns true if the request is active
     * @return signerMatch Checks if the signer of the request is valid
     * @return signer signer of the request
     */
    function _validate(
        ForwardExecuteData calldata request
    )
        internal
        view
        virtual
        returns (
            bool isTrustedForwarder,
            bool active,
            bool signerMatch,
            address signer
        )
    {
        (bool isValid, address recovered) = _recoverForwardSigner(request);

        return (
            TargetChecker._isTrustedByTarget(request.recipient),
            request.deadline >= block.timestamp,
            isValid && recovered == request.from,
            recovered
        );
    }

    /**
     * Recovers the signer of the request
     * @param request ForwardExecuteData struct
     * @return isValid If the signature is valid, returns true
     * @return recovered signer of the request
     */
    function _recoverForwardSigner(
        ForwardExecuteData calldata request
    ) internal view virtual returns (bool, address) {
        (address recovered, ECDSA.RecoverError err, ) = _hashTypedDataV4(
            hashEncodedRequest(request)
        ).tryRecover(request.signature);

        return (err == ECDSA.RecoverError.NoError, recovered);
    }

    /**
     * Encodes the parameters for the "executeTxWithForwarder" function of the Valerium contract for avoiding stack too deep error
     * @param request ForwardExecuteData struct
     */
    function hashEncodedRequest(
        ForwardExecuteData calldata request
    ) internal view virtual returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    FORWARD_EXECUTE_TYPEHASH,
                    request.from,
                    request.recipient,
                    request.deadline,
                    nonces(request.from),
                    request.gas,
                    keccak256(request.proof),
                    request.to,
                    request.value,
                    keccak256(request.data)
                )
            );
    }

    /**
     * Encodes the "executeBatchTxWithForwarder" function of the Valerium contract.
     * @param request ForwardExecuteBatchData struct
     * @param token The address of the token
     * @param gasPrice Estimated Gas Price for the transaction
     * @param baseGas Base Gas Fee for the transaction
     * @param estimatedFees estimated
     */
    function encodeExecuteBatchParams(
        ForwardExecuteBatchData calldata request,
        address token,
        uint256 gasPrice,
        uint256 baseGas,
        uint256 estimatedFees
    ) internal virtual returns (bytes memory encodedParams) {
        bytes4 functionSelector = IValerium
            .executeBatchTxWithForwarder
            .selector;

        encodedParams = abi.encodeWithSelector(
            functionSelector,
            request.proof,
            request.from,
            request.to,
            request.value,
            request.data,
            token,
            gasPrice,
            baseGas,
            estimatedFees
        );
    }

    /**
     * Validates the request by checking if the forwarder is trusted by the target, the request is active and the signer is valid
     * @param request ForwardExecuteBatchData struct
     * @return isTrustedForwarder If the forwarder is trusted by the target, returns true
     * @return active Checks the deadline of the request and returns true if the request is active
     * @return signerMatch Checks if the signer of the request is valid
     * @return signer signer of the request
     */
    function _validate(
        ForwardExecuteBatchData calldata request
    )
        internal
        view
        virtual
        returns (
            bool isTrustedForwarder,
            bool active,
            bool signerMatch,
            address signer
        )
    {
        (bool isValid, address recovered) = _recoverForwardSigner(request);

        return (
            TargetChecker._isTrustedByTarget(request.recipient),
            request.deadline >= block.timestamp,
            isValid && recovered == request.from,
            recovered
        );
    }

    /**
     * Recovers the signer of the request
     * @param request ForwardExecuteBatchData struct
     * @return isValid If the signature is valid, returns true
     * @return recovered signer of the request
     */
    function _recoverForwardSigner(
        ForwardExecuteBatchData calldata request
    ) internal view virtual returns (bool, address) {
        require(
            request.to.length == request.data.length &&
                (request.value.length == 0 ||
                    request.value.length == request.data.length),
            "Mismatched input arrays"
        );

        (address recovered, ECDSA.RecoverError err, ) = _hashTypedDataV4(
            hashEncodedRequest(request)
        ).tryRecover(request.signature);

        return (err == ECDSA.RecoverError.NoError, recovered);
    }

    /**
     * Encodes the parameters for the "executeBatchTxWithForwarder" function of the Valerium contract for avoiding stack too deep error
     * @param request ForwardExecuteBatchData struct
     */
    function hashEncodedRequest(
        ForwardExecuteBatchData calldata request
    ) internal view virtual returns (bytes32) {
        bytes32 dataHash;
        for (uint i = 0; i < request.data.length; i++) {
            dataHash = keccak256(
                abi.encodePacked(dataHash, keccak256(request.data[i]))
            );
        }
        bytes32 addressHash;
        for (uint i = 0; i < request.to.length; i++) {
            addressHash = keccak256(
                abi.encodePacked(addressHash, request.to[i])
            );
        }
        bytes32 valueHash;
        for (uint i = 0; i < request.value.length; i++) {
            valueHash = keccak256(
                abi.encodePacked(valueHash, abi.encodePacked(request.value[i]))
            );
        }
        return
            keccak256(
                abi.encode(
                    FORWARD_EXECUTE_BATCH_TYPEHASH,
                    request.from,
                    request.recipient,
                    request.deadline,
                    nonces(request.from),
                    request.gas,
                    keccak256(request.proof),
                    addressHash,
                    valueHash,
                    dataHash
                )
            );
    }

    /**
     * Encodes the parameters for the "executeRecoveryWithForwarder" function of the Valerium contract to prevent stack too deep error
     * @param request ForwardExecuteRecoveryData struct
     * @param token token address
     * @param gasPrice gas price
     * @param baseGas base fees
     * @param estimatedFees estimated fees
     */
    function encodeExecuteRecoveryParams(
        ForwardExecuteRecoveryData calldata request,
        address token,
        uint256 gasPrice,
        uint256 baseGas,
        uint256 estimatedFees
    ) internal pure returns (bytes memory) {
        bytes4 functionSignature = IValerium
            .executeRecoveryWithForwarder
            .selector;
        return
            abi.encodeWithSelector(
                functionSignature,
                request.proof,
                request.from,
                request.newTxHash,
                request.newTxVerifier,
                request.publicStorage,
                token,
                gasPrice,
                baseGas,
                estimatedFees
            );
    }

    /**
     * Validates the request by checking if the forwarder is trusted by the target, the request is active and the signer is valid
     * @param request ForwardExecuteRecoveryData struct
     * @return isTrustedForwarder If the forwarder is trusted by the target, returns true
     * @return active Checks the deadline of the request and returns true if the request is active
     * @return signerMatch Checks if the signer of the request is valid
     * @return signer signer of the request
     */
    function _validate(
        ForwardExecuteRecoveryData calldata request
    )
        internal
        view
        virtual
        returns (
            bool isTrustedForwarder,
            bool active,
            bool signerMatch,
            address signer
        )
    {
        (bool isValid, address recovered) = _recoverForwardSigner(request);

        return (
            TargetChecker._isTrustedByTarget(request.recipient),
            request.deadline >= block.timestamp,
            isValid && recovered == request.from,
            recovered
        );
    }

    /**
     * Recovers the signer of the request
     * @param request ForwardExecuteRecoveryData struct
     * @return isValid If the signature is valid, returns true
     * @return recovered signer of the request
     */
    function _recoverForwardSigner(
        ForwardExecuteRecoveryData calldata request
    ) internal view virtual returns (bool, address) {
        (address recovered, ECDSA.RecoverError err, ) = _hashTypedDataV4(
            hashEncodedRequest(request)
        ).tryRecover(request.signature);

        return (err == ECDSA.RecoverError.NoError, recovered);
    }

    /**
     * Encodes the parameters for the "executeRecoveryWithForwarder" function of the Valerium contract to prevent stack too deep error
     * @param request ForwardExecuteRecoveryData struct
     */
    function hashEncodedRequest(
        ForwardExecuteRecoveryData calldata request
    ) internal view virtual returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    FORWARD_EXECUTE_RECOVERY_TYPEHASH,
                    request.from,
                    request.recipient,
                    request.deadline,
                    nonces(request.from),
                    request.gas,
                    keccak256(request.proof),
                    request.newTxHash,
                    request.newTxVerifier,
                    keccak256(request.publicStorage)
                )
            );
    }

    /**
     * Encodes the parameters for the "changeRecoveryWithForwarder" function of the Valerium contract to prevent stack too deep error
     * @param request ForwardChangeRecoveryData struct
     * @param token token address
     * @param gasPrice gas price
     * @param baseGas base fees
     * @param estimatedFees estimated fees
     */
    function encodeChangeRecoveryParams(
        ForwardChangeRecoveryData calldata request,
        address token,
        uint256 gasPrice,
        uint256 baseGas,
        uint256 estimatedFees
    ) internal pure returns (bytes memory) {
        bytes4 functionSignature = IValerium
            .changeRecoveryWithForwarder
            .selector;
        return
            abi.encodeWithSelector(
                functionSignature,
                request.proof,
                request.from,
                request.newRecoveryHash,
                request.newRecoveryVerifier,
                request.publicStorage,
                token,
                gasPrice,
                baseGas,
                estimatedFees
            );
    }

    /**
     * Validates the request by checking if the forwarder is trusted by the target, the request is active and the signer is valid
     * @param request ForwardChangeRecoveryData struct
     * @return isTrustedForwarder If the forwarder is trusted by the target, returns true
     * @return active Checks the deadline of the request and returns true if the request is active
     * @return signerMatch Checks if the signer of the request is valid
     * @return signer signer of the request
     */
    function _validate(
        ForwardChangeRecoveryData calldata request
    )
        internal
        view
        virtual
        returns (
            bool isTrustedForwarder,
            bool active,
            bool signerMatch,
            address signer
        )
    {
        (bool isValid, address recovered) = _recoverForwardSigner(request);

        return (
            TargetChecker._isTrustedByTarget(request.recipient),
            request.deadline >= block.timestamp,
            isValid && recovered == request.from,
            recovered
        );
    }

    /**
     * Recovers the signer of the request
     * @param request ForwardChangeRecoveryData struct
     * @return isValid If the signature is valid, returns true
     * @return recovered signer of the request
     */
    function _recoverForwardSigner(
        ForwardChangeRecoveryData calldata request
    ) internal view virtual returns (bool, address) {
        (address recovered, ECDSA.RecoverError err, ) = _hashTypedDataV4(
            hashEncodedRequest(request)
        ).tryRecover(request.signature);

        return (err == ECDSA.RecoverError.NoError, recovered);
    }

    /**
     * Encodes the parameters for the "changeRecoveryWithForwarder" function of the Valerium contract to prevent stack too deep error
     * @param request ForwardChangeRecoveryData struct
     */
    function hashEncodedRequest(
        ForwardChangeRecoveryData calldata request
    ) internal view virtual returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    FORWARD_CHANGE_RECOVERY_TYPEHASH,
                    request.from,
                    request.recipient,
                    request.deadline,
                    nonces(request.from),
                    request.gas,
                    keccak256(request.proof),
                    request.newRecoveryHash,
                    request.newRecoveryVerifier,
                    keccak256(request.publicStorage)
                )
            );
    }
}

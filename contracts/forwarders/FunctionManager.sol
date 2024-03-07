// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/Nonces.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./DataManager.sol";
import "../external/ERC2771Context.sol";

interface IValerium {
    /**
     * @notice Executes a transaction with provided parameters using the trusted forwarder
     * @param _proof The proof input
     * @param to The address of the receiver
     * @param value The amount of Ether to send
     * @param data The data payload
     * @param token The address of the token, if the address is 0x0, it is an Ether transaction
     * @param gasPrice The gas price
     * @param baseGas The base gas
     * @param estimatedFees The estimated fees
     * @return success boolean flag indicating if the call succeeded
     */
    function executeTxWithForwarder(
        bytes calldata _proof,
        address to, 
        uint256 value, 
        bytes calldata data, 
        address token,
        uint256 gasPrice, 
        uint256 baseGas, 
        uint256 estimatedFees
        ) external payable returns(bool success);

    /**
     * @notice Executes a batch of transactions with provided parameters using the trusted forwarder
     * @param _proof The proof input
     * @param to Array of destination addresses
     * @param value Array of Ether values
     * @param data Array of data payloads
     * @param token The address of the token, if the address is 0x0, it is an Ether transaction
     * @param gasPrice The gas price
     * @param baseGas The base gas
     * @param estimatedFees The estimated fees
     */
    function executeBatchTxWithForwarder(
        bytes calldata _proof, 
        address[] calldata to, 
        uint256[] calldata value, 
        bytes[] calldata data, 
        address token,
        uint256 gasPrice, 
        uint256 baseGas, 
        uint256 estimatedFees
        ) external payable returns(bool success);

    /**
     * @notice Executes a recovery transaction to change the transaction hash, transaction verifier and public storage using the trusted forwarder
     * @param _proof The proof input
     * @param _newTxHash The new transaction hash
     * @param _newTxVerifier The address of the new transaction verifier
     * @param _publicStorage The new public storage
     * @param token The address of the token, if the address is 0x0, it is an Ether transaction
     * @param gasPrice The gas price
     * @param baseGas The base gas
     * @param estimatedFees The estimated fees
     */
    function executeRecoveryWithForwarder(
        bytes calldata _proof, 
        bytes32 _newTxHash, 
        address _newTxVerifier, 
        bytes calldata _publicStorage, 
        address token,
        uint256 gasPrice, 
        uint256 baseGas, 
        uint256 estimatedFees
        ) external payable;

    /**
     * @notice Executes a recovery transaction to change the recovery hash, recovery verifier and public storage using the trusted forwarder
     * @param _proof The proof input
     * @param _newRecoveryHash The new recovery hash
     * @param _newRecoveryVerifier The address of the new recovery verifier
     * @param _publicStorage The new public storage
     * @param token The address of the token, if the address is 0x0, it is an Ether transaction
     * @param gasPrice The gas price
     * @param baseGas The base gas
     * @param estimatedFees The estimated fees
     */
    function changeRecoveryWithForwarder(
        bytes calldata _proof, 
        bytes32 _newRecoveryHash, 
        address _newRecoveryVerifier, 
        bytes calldata _publicStorage,
        address token,
        uint256 gasPrice, 
        uint256 baseGas, 
        uint256 estimatedFees
        ) external payable;
}

abstract contract FunctionManager is EIP712, Nonces, DataManager {
    using ECDSA for bytes32;

    error ERC2771ForwarderMismatchedValue(uint256 requestedValue, uint256 msgValue);
    error ERC2771ForwarderExpiredRequest(uint48 deadline);
    error ERC2771UntrustfulTarget(address target, address forwarder);
    error ERC2771ForwarderInvalidSigner(address signer, address from);

    // Initializing EIP-712 Domain Separator
    constructor(string memory name, string memory version) EIP712(name, version) {}

    //           _____                                            _____                    _____                    _____                _____                    _____          
    //          /\    \                 ______                   /\    \                  /\    \                  /\    \              /\    \                  /\    \         
    //         /::\    \               |::|   |                 /::\    \                /::\    \                /::\____\            /::\    \                /::\    \        
    //        /::::\    \              |::|   |                /::::\    \              /::::\    \              /:::/    /            \:::\    \              /::::\    \       
    //       /::::::\    \             |::|   |               /::::::\    \            /::::::\    \            /:::/    /              \:::\    \            /::::::\    \      
    //      /:::/\:::\    \            |::|   |              /:::/\:::\    \          /:::/\:::\    \          /:::/    /                \:::\    \          /:::/\:::\    \     
    //     /:::/__\:::\    \           |::|   |             /:::/__\:::\    \        /:::/  \:::\    \        /:::/    /                  \:::\    \        /:::/__\:::\    \    
    //    /::::\   \:::\    \          |::|   |            /::::\   \:::\    \      /:::/    \:::\    \      /:::/    /                   /::::\    \      /::::\   \:::\    \   
    //   /::::::\   \:::\    \         |::|   |           /::::::\   \:::\    \    /:::/    / \:::\    \    /:::/    /      _____        /::::::\    \    /::::::\   \:::\    \  
    //  /:::/\:::\   \:::\    \  ______|::|___|___ ____  /:::/\:::\   \:::\    \  /:::/    /   \:::\    \  /:::/____/      /\    \      /:::/\:::\    \  /:::/\:::\   \:::\    \ 
    // /:::/__\:::\   \:::\____\|:::::::::::::::::|    |/:::/__\:::\   \:::\____\/:::/____/     \:::\____\|:::|    /      /::\____\    /:::/  \:::\____\/:::/__\:::\   \:::\____\
    // \:::\   \:::\   \::/    /|:::::::::::::::::|____|\:::\   \:::\   \::/    /\:::\    \      \::/    /|:::|____\     /:::/    /   /:::/    \::/    /\:::\   \:::\   \::/    /
    //  \:::\   \:::\   \/____/  ~~~~~~|::|~~~|~~~       \:::\   \:::\   \/____/  \:::\    \      \/____/  \:::\    \   /:::/    /   /:::/    / \/____/  \:::\   \:::\   \/____/ 
    //   \:::\   \:::\    \            |::|   |           \:::\   \:::\    \       \:::\    \               \:::\    \ /:::/    /   /:::/    /            \:::\   \:::\    \     
    //    \:::\   \:::\____\           |::|   |            \:::\   \:::\____\       \:::\    \               \:::\    /:::/    /   /:::/    /              \:::\   \:::\____\    
    //     \:::\   \::/    /           |::|   |             \:::\   \::/    /        \:::\    \               \:::\__/:::/    /    \::/    /                \:::\   \::/    /    
    //      \:::\   \/____/            |::|   |              \:::\   \/____/          \:::\    \               \::::::::/    /      \/____/                  \:::\   \/____/     
    //       \:::\    \                |::|   |               \:::\    \               \:::\    \               \::::::/    /                                 \:::\    \         
    //        \:::\____\               |::|   |                \:::\____\               \:::\____\               \::::/    /                                   \:::\____\        
    //         \::/    /               |::|___|                 \::/    /                \::/    /                \::/____/                                     \::/    /        
    //          \/____/                 ~~                       \/____/                  \/____/                  ~~                                            \/____/                                                 

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
    ) internal virtual returns (bool success) {
          {
            (bool isTrustedForwarder, bool active, bool signerMatch, address signer) = _validate(request);

            // Need to explicitly specify if a revert is required since non-reverting is default for
            // batches and reversion is opt-in since it could be useful in some scenarios
            if (requireValidRequest) {
                if (!isTrustedForwarder) {
                    revert ERC2771UntrustfulTarget(request.recipient, address(this));
                }

                if (!active) {
                    revert ERC2771ForwarderExpiredRequest(request.deadline);
                }

                if (!signerMatch) {
                    revert ERC2771ForwarderInvalidSigner(signer, request.from);
                }
            }

            // Ignore an invalid request because requireValidRequest = false
            if(!isTrustedForwarder || !active || !signerMatch) {
                return false;
            }

            // Nonce should be used before the call to prevent reusing by reentrancy
            _useNonce(signer);

        }

        uint256 gasLeft;

        address recipient = request.recipient;
        uint256 reqGas = request.gas;

        // Encode the parameters for optimized gas usage
        bytes memory encodedParams = encodeExecuteParams(request, token, gasPrice, baseGas, estimatedFees);

        assembly {
            let encodedParamsData := add(encodedParams, 0x20)  // Skip the length field of the bytes array
            let encodedParamsLength := mload(encodedParams)  // Get the length of the bytes array

            success := call(
                reqGas,
                recipient,
                0,
                encodedParamsData,
                encodedParamsLength,
                0,
                0
            )

            gasLeft := gas()
        }

        _checkForwardedGas(gasLeft, request);
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
        return abi.encodePacked(
            functionSignature,
            request.proof,
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
    ) internal view virtual returns (bool isTrustedForwarder, bool active, bool signerMatch, address signer) {
        (bool isValid, address recovered) = _recoverForwardSigner(request);

        return (
            _isTrustedByTarget(request.to),
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
        return keccak256(
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
     * Checks if the gas forwarded is sufficient
     * @param gasLeft gas left after the forwarding
     * @param request ForwardExecuteData struct
     */
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

    //           _____                    _____                _____                    _____                    _____          
    //          /\    \                  /\    \              /\    \                  /\    \                  /\    \         
    //         /::\    \                /::\    \            /::\    \                /::\    \                /::\____\        
    //        /::::\    \              /::::\    \           \:::\    \              /::::\    \              /:::/    /        
    //       /::::::\    \            /::::::\    \           \:::\    \            /::::::\    \            /:::/    /         
    //      /:::/\:::\    \          /:::/\:::\    \           \:::\    \          /:::/\:::\    \          /:::/    /          
    //     /:::/__\:::\    \        /:::/__\:::\    \           \:::\    \        /:::/  \:::\    \        /:::/____/           
    //    /::::\   \:::\    \      /::::\   \:::\    \          /::::\    \      /:::/    \:::\    \      /::::\    \           
    //   /::::::\   \:::\    \    /::::::\   \:::\    \        /::::::\    \    /:::/    / \:::\    \    /::::::\    \   _____  
    //  /:::/\:::\   \:::\ ___\  /:::/\:::\   \:::\    \      /:::/\:::\    \  /:::/    /   \:::\    \  /:::/\:::\    \ /\    \ 
    // /:::/__\:::\   \:::|    |/:::/  \:::\   \:::\____\    /:::/  \:::\____\/:::/____/     \:::\____\/:::/  \:::\    /::\____\
    // \:::\   \:::\  /:::|____|\::/    \:::\  /:::/    /   /:::/    \::/    /\:::\    \      \::/    /\::/    \:::\  /:::/    /
    //  \:::\   \:::\/:::/    /  \/____/ \:::\/:::/    /   /:::/    / \/____/  \:::\    \      \/____/  \/____/ \:::\/:::/    / 
    //   \:::\   \::::::/    /            \::::::/    /   /:::/    /            \:::\    \                       \::::::/    /  
    //    \:::\   \::::/    /              \::::/    /   /:::/    /              \:::\    \                       \::::/    /   
    //     \:::\  /:::/    /               /:::/    /    \::/    /                \:::\    \                      /:::/    /    
    //      \:::\/:::/    /               /:::/    /      \/____/                  \:::\    \                    /:::/    /     
    //       \::::::/    /               /:::/    /                                 \:::\    \                  /:::/    /      
    //        \::::/    /               /:::/    /                                   \:::\____\                /:::/    /       
    //         \::/____/                \::/    /                                     \::/    /                \::/    /        
    //          ~~                       \/____/                                       \/____/                  \/____/         
                                                                                                                            

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
    ) internal virtual returns (bool success) {
        (bool isTrustedForwarder, bool active, bool signerMatch, address signer) = _validate(request);

        // Need to explicitly specify if a revert is required since non-reverting is default for
        // batches and reversion is opt-in since it could be useful in some scenarios
        if (requireValidRequest) {
            if (!isTrustedForwarder) {
                revert ERC2771UntrustfulTarget(request.recipient, address(this));
            }

            if (!active) {
                revert ERC2771ForwarderExpiredRequest(request.deadline);
            }

            if (!signerMatch) {
                revert ERC2771ForwarderInvalidSigner(signer, request.from);
            }
        }

         // Ignore an invalid request because requireValidRequest = false
        if(!isTrustedForwarder || !active || !signerMatch) {
            return false;
        }

        // Nonce should be used before the call to prevent reusing by reentrancy
        _useNonce(signer);

        success = executeBatchFromRequest(request, token, gasPrice, baseGas, estimatedFees);

        _checkForwardedGas(gasleft(), request);
    }

    /**
     * Executes the "executeBatchTxWithForwarder" function of the Valerium contract.
     * @param request ForwardExecuteBatchData struct
     * @param token The address of the token
     * @param gasPrice Estimated Gas Price for the transaction
     * @param baseGas Base Gas Fee for the transaction
     * @param estimatedFees estimated
     */
    function executeBatchFromRequest(
        ForwardExecuteBatchData calldata request,
        address token,
        uint256 gasPrice,
        uint256 baseGas,
        uint256 estimatedFees
    ) internal virtual returns (bool success) {
        return IValerium(payable(request.recipient)).executeBatchTxWithForwarder(
            request.proof,
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
    ) internal view virtual returns (bool isTrustedForwarder, bool active, bool signerMatch, address signer) {
        (bool isValid, address recovered) = _recoverForwardSigner(request);

        return (
            _isTrustedByTarget(request.recipient),
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
        require(request.to.length == request.value.length && request.to.length == request.data.length, "Mismatched input arrays");

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
            dataHash = keccak256(abi.encodePacked(dataHash, keccak256(request.data[i])));
        }
        return keccak256(
            abi.encode(
                FORWARD_EXECUTE_BATCH_TYPEHASH,
                request.from,
                request.recipient,
                request.deadline,
                nonces(request.from),
                request.gas,
                keccak256(request.proof),
                keccak256(abi.encodePacked(request.to)),
                keccak256(abi.encodePacked(request.value)),
                dataHash
            )
        );
    }

    /**
     * Checks if the gas forwarded is sufficient
     * @param gasLeft gas left after the forwarding
     * @param request ForwardExecuteBatchData struct
     */
    function _checkForwardedGas(uint256 gasLeft, ForwardExecuteBatchData calldata request) private pure {
        if (gasLeft < request.gas / 63) {
            assembly {
                invalid()
            }
        }
    }

    //           _____                    _____                    _____                   _______                   _____                    _____                    _____                _____          
    //          /\    \                  /\    \                  /\    \                 /::\    \                 /\    \                  /\    \                  /\    \              |\    \         
    //         /::\    \                /::\    \                /::\    \               /::::\    \               /::\____\                /::\    \                /::\    \             |:\____\        
    //        /::::\    \              /::::\    \              /::::\    \             /::::::\    \             /:::/    /               /::::\    \              /::::\    \            |::|   |        
    //       /::::::\    \            /::::::\    \            /::::::\    \           /::::::::\    \           /:::/    /               /::::::\    \            /::::::\    \           |::|   |        
    //      /:::/\:::\    \          /:::/\:::\    \          /:::/\:::\    \         /:::/~~\:::\    \         /:::/    /               /:::/\:::\    \          /:::/\:::\    \          |::|   |        
    //     /:::/__\:::\    \        /:::/__\:::\    \        /:::/  \:::\    \       /:::/    \:::\    \       /:::/____/               /:::/__\:::\    \        /:::/__\:::\    \         |::|   |        
    //    /::::\   \:::\    \      /::::\   \:::\    \      /:::/    \:::\    \     /:::/    / \:::\    \      |::|    |               /::::\   \:::\    \      /::::\   \:::\    \        |::|   |        
    //   /::::::\   \:::\    \    /::::::\   \:::\    \    /:::/    / \:::\    \   /:::/____/   \:::\____\     |::|    |     _____    /::::::\   \:::\    \    /::::::\   \:::\    \       |::|___|______  
    //  /:::/\:::\   \:::\____\  /:::/\:::\   \:::\    \  /:::/    /   \:::\    \ |:::|    |     |:::|    |    |::|    |    /\    \  /:::/\:::\   \:::\    \  /:::/\:::\   \:::\____\      /::::::::\    \ 
    // /:::/  \:::\   \:::|    |/:::/__\:::\   \:::\____\/:::/____/     \:::\____\|:::|____|     |:::|    |    |::|    |   /::\____\/:::/__\:::\   \:::\____\/:::/  \:::\   \:::|    |    /::::::::::\____\
    // \::/   |::::\  /:::|____|\:::\   \:::\   \::/    /\:::\    \      \::/    / \:::\    \   /:::/    /     |::|    |  /:::/    /\:::\   \:::\   \::/    /\::/   |::::\  /:::|____|   /:::/~~~~/~~      
    //  \/____|:::::\/:::/    /  \:::\   \:::\   \/____/  \:::\    \      \/____/   \:::\    \ /:::/    /      |::|    | /:::/    /  \:::\   \:::\   \/____/  \/____|:::::\/:::/    /   /:::/    /         
    //        |:::::::::/    /    \:::\   \:::\    \       \:::\    \                \:::\    /:::/    /       |::|____|/:::/    /    \:::\   \:::\    \            |:::::::::/    /   /:::/    /          
    //        |::|\::::/    /      \:::\   \:::\____\       \:::\    \                \:::\__/:::/    /        |:::::::::::/    /      \:::\   \:::\____\           |::|\::::/    /   /:::/    /           
    //        |::| \::/____/        \:::\   \::/    /        \:::\    \                \::::::::/    /         \::::::::::/____/        \:::\   \::/    /           |::| \::/____/    \::/    /            
    //        |::|  ~|               \:::\   \/____/          \:::\    \                \::::::/    /           ~~~~~~~~~~               \:::\   \/____/            |::|  ~|           \/____/             
    //        |::|   |                \:::\    \               \:::\    \                \::::/    /                                      \:::\    \                |::|   |                               
    //        \::|   |                 \:::\____\               \:::\____\                \::/____/                                        \:::\____\               \::|   |                               
    //         \:|   |                  \::/    /                \::/    /                 ~~                                               \::/    /                \:|   |                               
    //          \|___|                   \/____/                  \/____/                                                                    \/____/                  \|___|                               


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
    ) internal virtual returns (bool success){
        {
            (bool isTrustedForwarder, bool active, bool signerMatch, address signer) = _validate(request);

            // Need to explicitly specify if a revert is required since non-reverting is default for
            // batches and reversion is opt-in since it could be useful in some scenarios
            if (requireValidRequest) {
                if (!isTrustedForwarder) {
                    revert ERC2771UntrustfulTarget(request.recipient, address(this));
                }

                if (!active) {
                    revert ERC2771ForwarderExpiredRequest(request.deadline);
                }

                if (!signerMatch) {
                    revert ERC2771ForwarderInvalidSigner(signer, request.from);
                }
            }

            // Ignore an invalid request because requireValidRequest = false
            if(!isTrustedForwarder || !active || !signerMatch) {
                return false;
            }

            // Nonce should be used before the call to prevent reusing by reentrancy
            _useNonce(signer);

        }

        address recipient = request.recipient;
        uint256 reqGas = request.gas;
        
        // Encode the parameters for more efficient gas usage
        bytes memory encodedParams = encodeExecuteRecoveryParams(request, token, gasPrice, baseGas, estimatedFees);
            
        uint256 gasLeft;
        assembly {
            let encodedParamsData := add(encodedParams, 0x20)  // Skip the length field of the bytes array
            let encodedParamsLength := mload(encodedParams)  // Get the length of the bytes array

            success := call(
                reqGas,
                recipient,
                0,
                encodedParamsData,
                encodedParamsLength,
                0,
                0
            )

            gasLeft := gas()
        }

        _checkForwardedGas(gasLeft, request);

        return true;
        
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
        bytes4 functionSignature = IValerium.executeRecoveryWithForwarder.selector;
        return abi.encodePacked(
                functionSignature,
                request.proof,
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
    ) internal view virtual returns (bool isTrustedForwarder, bool active, bool signerMatch, address signer) {
        (bool isValid, address recovered) = _recoverForwardSigner(request);

        return (
            _isTrustedByTarget(request.recipient),
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
        return keccak256(
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
     * Checks if the gas forwarded is sufficient
     * @param gasLeft gas left after the forwarding
     * @param request ForwardExecuteRecoveryData struct
     */
    function _checkForwardedGas(uint256 gasLeft, ForwardExecuteRecoveryData calldata request) private pure {
        if (gasLeft < request.gas / 63) {
            assembly {
                invalid()
            }
        }
    }          
    
    //           _____                    _____                    _____                    _____                    _____                    _____          
    //          /\    \                  /\    \                  /\    \                  /\    \                  /\    \                  /\    \         
    //         /::\    \                /::\____\                /::\    \                /::\____\                /::\    \                /::\    \        
    //        /::::\    \              /:::/    /               /::::\    \              /::::|   |               /::::\    \              /::::\    \       
    //       /::::::\    \            /:::/    /               /::::::\    \            /:::::|   |              /::::::\    \            /::::::\    \      
    //      /:::/\:::\    \          /:::/    /               /:::/\:::\    \          /::::::|   |             /:::/\:::\    \          /:::/\:::\    \     
    //     /:::/  \:::\    \        /:::/____/               /:::/__\:::\    \        /:::/|::|   |            /:::/  \:::\    \        /:::/__\:::\    \    
    //    /:::/    \:::\    \      /::::\    \              /::::\   \:::\    \      /:::/ |::|   |           /:::/    \:::\    \      /::::\   \:::\    \   
    //   /:::/    / \:::\    \    /::::::\    \   _____    /::::::\   \:::\    \    /:::/  |::|   | _____    /:::/    / \:::\    \    /::::::\   \:::\    \  
    //  /:::/    /   \:::\    \  /:::/\:::\    \ /\    \  /:::/\:::\   \:::\    \  /:::/   |::|   |/\    \  /:::/    /   \:::\ ___\  /:::/\:::\   \:::\    \ 
    // /:::/____/     \:::\____\/:::/  \:::\    /::\____\/:::/  \:::\   \:::\____\/:: /    |::|   /::\____\/:::/____/  ___\:::|    |/:::/__\:::\   \:::\____\
    // \:::\    \      \::/    /\::/    \:::\  /:::/    /\::/    \:::\  /:::/    /\::/    /|::|  /:::/    /\:::\    \ /\  /:::|____|\:::\   \:::\   \::/    /
    //  \:::\    \      \/____/  \/____/ \:::\/:::/    /  \/____/ \:::\/:::/    /  \/____/ |::| /:::/    /  \:::\    /::\ \::/    /  \:::\   \:::\   \/____/ 
    //   \:::\    \                       \::::::/    /            \::::::/    /           |::|/:::/    /    \:::\   \:::\ \/____/    \:::\   \:::\    \     
    //    \:::\    \                       \::::/    /              \::::/    /            |::::::/    /      \:::\   \:::\____\       \:::\   \:::\____\    
    //     \:::\    \                      /:::/    /               /:::/    /             |:::::/    /        \:::\  /:::/    /        \:::\   \::/    /    
    //      \:::\    \                    /:::/    /               /:::/    /              |::::/    /          \:::\/:::/    /          \:::\   \/____/     
    //       \:::\    \                  /:::/    /               /:::/    /               /:::/    /            \::::::/    /            \:::\    \         
    //        \:::\____\                /:::/    /               /:::/    /               /:::/    /              \::::/    /              \:::\____\        
    //         \::/    /                \::/    /                \::/    /                \::/    /                \::/____/                \::/    /        
    //          \/____/                  \/____/                  \/____/                  \/____/                                           \/____/     


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
    ) internal virtual returns (bool success){
        {
            (bool isTrustedForwarder, bool active, bool signerMatch, address signer) = _validate(request);

            // Need to explicitly specify if a revert is required since non-reverting is default for
            // batches and reversion is opt-in since it could be useful in some scenarios
            if (requireValidRequest) {
                if (!isTrustedForwarder) {
                    revert ERC2771UntrustfulTarget(request.recipient, address(this));
                }

                if (!active) {
                    revert ERC2771ForwarderExpiredRequest(request.deadline);
                }

                if (!signerMatch) {
                    revert ERC2771ForwarderInvalidSigner(signer, request.from);
                }
            }

            // Ignore an invalid request because requireValidRequest = false
            if(!isTrustedForwarder || !active || !signerMatch) {
                return false;
            }

            // Nonce should be used before the call to prevent reusing by reentrancy
            _useNonce(signer);
        }

        uint256 gasLeft;

        address recipient = request.recipient;
        uint256 reqGas = request.gas;

        // Encode the parameters for more efficient gas usage
        bytes memory encodedParams = encodeChangeRecoveryParams(request, token, gasPrice, baseGas, estimatedFees);

        assembly {
            let encodedParamsData := add(encodedParams, 0x20)  // Skip the length field of the bytes array
            let encodedParamsLength := mload(encodedParams)  // Get the length of the bytes array

            success := call(
                reqGas,
                recipient,
                0,
                encodedParamsData,
                encodedParamsLength,
                0,
                0
            )

            gasLeft := gas()
        }
            
        _checkForwardedGas(gasLeft, request);

        return true;
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
        bytes4 functionSignature = IValerium.changeRecoveryWithForwarder.selector;
        return abi.encodePacked(
            functionSignature,
            request.proof,
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
    ) internal view virtual returns (bool isTrustedForwarder, bool active, bool signerMatch, address signer) {
        (bool isValid, address recovered) = _recoverForwardSigner(request);

        return (
            _isTrustedByTarget(request.recipient),
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
        return keccak256(
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

    /**
     * Checks if the gas forwarded is sufficient
     * @param gasLeft gas left after the forwarding
     * @param request ForwardChangeRecoveryData struct
     */
    function _checkForwardedGas(uint256 gasLeft, ForwardChangeRecoveryData calldata request) private pure {
        if (gasLeft < request.gas / 63) {
            assembly {
                invalid()
            }
        }
    }                                                                                                                                                                                                                                                                                                                   

     /**
     * Checks if the forwarder is trusted by the target
     * @param target address of the target contract
     */
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
}
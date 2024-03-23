// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../external/ERC2771Context.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/Nonces.sol";

/**
 * @title FactoryForwarder - A contract that forwards transactions to a ValeriumFactory Contract.
 * @notice This contract is specifically designed to be used with the Valerium Factory Contract, 
 *         and some function may not work as expected if used with other contracts. To be used
 *         to deploy Valerium Waller through Valerium Factory Contract.
 * @author Anoy Roy Chwodhury - <anoyroyc3545@gmail.com>
 */

interface IValeriumProxyFactory {
    function createProxyWithNonce(bytes calldata serverProof, string memory domain, bytes memory initializer, uint256 saltNonce) external;
}

contract FactoryForwarder is EIP712, Nonces {
    using ECDSA for bytes32;

    error ERC2771ForwarderMismatchedValue(uint256 requestedValue, uint256 msgValue);
    error ERC2771ForwarderExpiredRequest(uint48 deadline);
    error ERC2771UntrustfulTarget(address target, address forwarder);
    error ERC2771ForwarderInvalidSigner(address signer, address from);
    error DeploymentFailed();

    // Initializing the EIP712 Domain Separator
    constructor(string memory name, string memory version) EIP712(name, version) {}

    // struct of forwarded message for "createProxyWithNonce" function
    struct ForwardDeployData {
        address from;
        address recipient;
        uint48 deadline;
        uint256 gas;
        bytes serverProof;
        string domain;
        bytes initializer;
        uint256 salt;
        bytes signature;
    }

    // typehash of ForwardDeployData
    bytes32 internal constant FORWARD_DEPLOY_TYPEHASH = keccak256(
        "ForwardDeploy(address from,address recipient,uint48 deadline,uint256 nonce,uint256 gas,bytes serverProof,string domain,bytes initializer,uint256 salt)"
    );

    /**
     * @notice This function is used to execute the "createProxyWithNonce" function of the target contract.
     * @param request The struct of forwarded message for "createProxyWithNonce" function
     */
    function execute(ForwardDeployData calldata request) public payable virtual {
        require(msg.value == 0, "ValeriumForwarder: invalid msg.value");

        if (!_deploy(request, true)) {
            revert DeploymentFailed();
        }
    }


    /**
     * Executes the "createProxyWithNonce" function of the ValeriumFactory Contract
     * @param request ForwardChangeRecoveryData struct
     * @param requireValidRequest If true, the function will revert if the request is invalid
     */
    function _deploy(
        ForwardDeployData calldata request,
        bool requireValidRequest
    ) internal virtual returns (bool success){
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
        if (isTrustedForwarder && signerMatch && active) {
            // Nonce should be used before the call to prevent reusing by reentrancy
            _useNonce(signer);

            IValeriumProxyFactory(request.recipient).createProxyWithNonce(request.serverProof, request.domain, request.initializer, request.salt);

            _checkForwardedGas(gasleft(), request);

            return true;
        }
    }


     /**
     * Validates the request by checking if the forwarder is trusted by the target, the request is active and the signer is valid
     * @param request ForwardDeployData struct
     * @return isTrustedForwarder If the forwarder is trusted by the target, returns true
     * @return active Checks the deadline of the request and returns true if the request is active
     * @return signerMatch Checks if the signer of the request is valid
     * @return signer signer of the request
     */
    function _validate(
        ForwardDeployData calldata request
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
     * @param request ForwardDeployData struct
     * @return isValid If the signature is valid, returns true
     * @return recovered signer of the request
     */
    function _recoverForwardSigner(
        ForwardDeployData calldata request
    ) internal view virtual returns (bool, address) {
        (address recovered, ECDSA.RecoverError err, ) = _hashTypedDataV4(
            keccak256(abi.encode(
                FORWARD_DEPLOY_TYPEHASH,
                request.from,
                request.recipient,
                request.deadline,
                nonces(request.from),
                request.gas,
                keccak256(request.serverProof),
                keccak256(bytes(request.domain)),
                keccak256(request.initializer),
                request.salt
            ))
        ).tryRecover(request.signature);

        return (err == ECDSA.RecoverError.NoError, recovered);
    }

    /**
     * Checks if the gas forwarded is sufficient
     * @param gasLeft gas left after the forwarding
     * @param request ForwardChangeRecoveryData struct
     */
    function _checkForwardedGas(uint256 gasLeft, ForwardDeployData calldata request) private pure {
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


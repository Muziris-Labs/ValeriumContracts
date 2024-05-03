// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../external/Valerium2771Context.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/Nonces.sol";
import "./FactoryLogManager.sol";
import "./lib/ServerHandler.sol";
import "./lib/TargetChecker.sol";

/**
 * @title FactoryForwarder - A contract that forwards transactions to a ValeriumFactory Contract.
 * @notice This contract is specifically designed to be used with the Valerium Factory Contract, 
 *         and some function may not work as expected if used with other contracts. To be used
 *         to deploy Valerium Wallet through Valerium Factory Contract.
 * @author Anoy Roy Chwodhury - <anoyroyc3545@gmail.com>
 */

interface IValeriumProxyFactory {
    function createProxyWithNonce(string memory domain, bytes memory initializer, uint256 saltNonce) external;
}

contract FactoryForwarder is EIP712, Nonces, FactoryLogManager, ServerHandler {
    using ECDSA for bytes32;

    event DeploymentResult(bytes4 result);

    // isBase is used to check if the contract is in base chain
    bool immutable isBase;

    // Initializing the EIP712 Domain Separator
    constructor(string memory name, string memory version, bool _isBase) EIP712(name, version) {
        isBase = _isBase;
    }

    /**
     * @dev Modfier to check if the proof is valid (only for non-base chain)
     */
    modifier checkBase (bytes calldata serverProof, bytes4 domain) {
        if(!isBase) {
            require(verify(serverProof, serverHash, ServerVerifier, domain), "ValeriumForwarder: invalid serverProof");
        }
        _;
    }

    // struct of forwarded message for "createProxyWithNonce" function
    struct ForwardDeployData {
        address from;
        address recipient;
        uint48 deadline;
        uint256 gas;
        string domain;
        bytes initializer;
        uint256 salt;
        bytes signature;
    }

    // typehash of ForwardDeployData
    bytes32 internal constant FORWARD_DEPLOY_TYPEHASH = keccak256(
        "ForwardDeploy(address from,address recipient,uint48 deadline,uint256 nonce,uint256 gas,string domain,bytes initializer,uint256 salt)"
    );

    /**
     * @notice This function is used to execute the "createProxyWithNonce" function of the target contract.
     * @param request The struct of forwarded message for "createProxyWithNonce" function
     */
    function execute(bytes calldata serverProof, ForwardDeployData calldata request) 
        checkBase (serverProof,  bytes4(keccak256(abi.encodePacked(request.domain)))) 
        public payable virtual returns (bytes4 magicValue) {

        magicValue = _deploy(request, true);
        emit DeploymentResult(magicValue);
    }


    /**
     * Executes the "createProxyWithNonce" function of the ValeriumFactory Contract
     * @param request ForwardChangeRecoveryData struct
     * @param requireValidRequest If true, the function will revert if the request is invalid
     */
    function _deploy(
        ForwardDeployData calldata request,
        bool requireValidRequest
    ) internal virtual returns (bytes4 magicValue){
        (bool isTrustedForwarder, bool active, bool signerMatch, address signer) = _validate(request);

        // Need to explicitly specify if a revert is required since non-reverting is default for
        // batches and reversion is opt-in since it could be useful in some scenarios
        if (requireValidRequest) {
            if (!isTrustedForwarder) {
                return UNTRUSTFUL_TARGET;
            }

            if (!active) {
                return EXPIRED_REQUEST;
            }

            if (!signerMatch) {
                return INVALID_SIGNER;
            }
        }

        // Ignore an invalid request because requireValidRequest = false
        if (isTrustedForwarder && signerMatch && active) {
            // Nonce should be used before the call to prevent reusing by reentrancy
            _useNonce(signer);

            if(!_checkForwardedGas(gasleft(), request.gas)) {
                return INSUFFICIENT_BALANCE;
            }

            (bool success, ) = address(request.recipient).call{gas : request.gas}(
                abi.encodeWithSelector(
                    IValeriumProxyFactory.createProxyWithNonce.selector,
                    request.domain,
                    request.initializer,
                    request.salt
                )
            );

            if (!success) {
                return DEPLOYMENT_FAILED;
            }

            return DEPLOYMENT_SUCCESSFUL;
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
            TargetChecker._isTrustedByTarget(request.recipient),
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
     * @param requestGas gas requested for the forwarding
     */
    function _checkForwardedGas(uint256 gasLeft, uint256 requestGas) private pure returns (bool success) {
        if (gasLeft >= requestGas + (requestGas / 64)) {
            return false;
        }
        return true;
    }
}


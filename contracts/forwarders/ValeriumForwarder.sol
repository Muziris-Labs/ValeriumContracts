// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

import "./FunctionManager.sol";

/**
 * @title ValeriumForwarder - A contract that forwards transactions to a target contract.
 * @notice This contract is specifically designed to be used with the Valerium Wallet. Some function may not work as expected if used with other wallets.
 * @author Anoy Roy Chwodhury - <anoyroyc3545@gmail.com>
 */

contract ValeriumForwarder is FunctionManager {
    error ERC2771ForwarderInvalidSigner(address signer, address from);

    constructor(string memory name, string memory version) FunctionManager(name, version) {}

    /**
     * @notice This function is used to execute the "executeWithForwarder" function of the target contract.
     * @param request The struct of forwarded message for "executeWithForwarder" function
     * @param token The address of the token
     * @param gasPrice The gas price of the transaction
     * @param baseGas The base gas of the transaction
     * @param estimatedFees The estimated fees of the transaction
     */
    function execute(ForwardExecuteData calldata request, address token, uint256 gasPrice, uint256 baseGas, uint256 estimatedFees) public payable virtual {
        require(msg.value == 0, "ValeriumForwarder: invalid msg.value");

        if (!_execute(request, token, gasPrice, baseGas, estimatedFees, true)) {
            revert ERC2771ForwarderInvalidSigner(request.from, msg.sender);
        }
    }

    /**
     * @notice This function is used to execute the "executeBatchWithForwarder" function of the target contract.
     * @param request The struct of forwarded message for "executeBatchWithForwarder" function
     * @param token The address of the token
     * @param gasPrice The gas price of the transaction
     * @param baseGas The base gas of the transaction
     * @param estimatedFees The estimated fees of the transaction
     */

    function executeBatch(ForwardExecuteBatchData calldata request, address token, uint256 gasPrice, uint256 baseGas, uint256 estimatedFees) public payable virtual {
        require(msg.value == 0, "ValeriumForwarder: invalid msg.value");

        if (!_executeBatch(request, token, gasPrice, baseGas, estimatedFees, true)) {
            revert ERC2771ForwarderInvalidSigner(request.from, msg.sender);
        }
    }

    /**
     * @notice This function is used to execute the "executeRecoveryWithForwarder" function of the target contract.
     * @param request The struct of forwarded message for "executeRecoveryWithForwarder" function
     * @param token The address of the token
     * @param gasPrice The gas price of the transaction
     * @param baseGas The base gas of the transaction
     * @param estimatedFees The estimated fees of the transaction
     */

    function executeRecovery(ForwardExecuteRecoveryData calldata request, address token, uint256 gasPrice, uint256 baseGas, uint256 estimatedFees) public payable virtual {
        require(msg.value == 0, "ValeriumForwarder: invalid msg.value");

        if (!_executeRecovery(request, token, gasPrice, baseGas, estimatedFees, true)) {
            revert ERC2771ForwarderInvalidSigner(request.from, msg.sender);
        }
    }

    /**
     * @notice This function is used to execute the "changeRecoveryWithForwarder" function of the target contract.
     * @param request The struct of forwarded message for "changeRecoveryWithForwarder" function
     * @param token The address of the token
     * @param gasPrice The gas price of the transaction
     * @param baseGas The base gas of the transaction
     * @param estimatedFees The estimated fees of the transaction
     */
    function changeRecovery(ForwardChangeRecoveryData calldata request, address token, uint256 gasPrice, uint256 baseGas, uint256 estimatedFees) public payable virtual {
        require(msg.value == 0, "ValeriumForwarder: invalid msg.value");

        if (!_changeRecovery(request, token, gasPrice, baseGas, estimatedFees, true)) {
            revert ERC2771ForwarderInvalidSigner(request.from, msg.sender);
        }
    }
}


// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

/**
 * @title IValerium - Interface for the Valerium contract
 * @author Anoy Roy Chowdhury - <anoyroyc3545@gmail.com>
 * @notice Interface for the Valerium Singleton contract
 */

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
     * @return magicValue The magic value of the transaction
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
        ) external payable returns(bytes4 magicValue);

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
     * @return magicValue bytes4 indicating the status of the execution
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
        ) external payable returns(bytes4 magicValue);

   
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
     * @return magicValue bytes4 indicating the status of the execution
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
        ) external payable returns (bytes4 magicValue);

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
     * @return magicValue bytes4 indicating the status of the execution
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
        ) external payable returns (bytes4 magicValue);
}
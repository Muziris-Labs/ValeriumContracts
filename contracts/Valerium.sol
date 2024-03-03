// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

import "./common/Singleton.sol";
import "./common/StorageAccessible.sol";
import "./base/Executor.sol";
import "./base/ProofManager.sol";
import "./handler/TokenCallbackHandler.sol";
import "./external/ERC2771Context.sol";

/**
 * @title Valerium - A Smart Contract Wallet powered by ZK-SNARKs with support for Cross-Chain Transactions
 * @dev Most important concepts :
 *    - TxVerifier: Address of the Noir based ZK-SNARK verifier contract that will be used to verify proofs and execute transactions on the Valerium Wallet
 *    - RecoveryVerifier: Address of the Noir based ZK-SNARK verifier contract that will be used to verify proofs and execute recovery transactions on the Valerium Wallet
 *    - Gas Tank: The gas tank is a smart contract that deducts gas fees from the user's Valerium Wallet.
 *    - Public Storage: The public storage of the Valerium Wallet
 *    - DOMAIN: The domain of the Valerium Wallet
 *    - TxHash: The hash used as a public inputs for the transaction verifier
 *    - RecoveryHash: The hash used as a public inputs for the recovery verifier
 *    - nonce: The nonce of the Valerium Wallet
 * @author Anoy Roy Chowdhury - <anoyroyc3545@gmail.com>
 */

contract Valerium is
    Singleton,
    StorageAccessible,
    Executor,
    ProofManager,
    TokenCallbackHandler,
    ERC2771Context
{
    string public constant VERSION = "1.0.0";

    // The domain of the Valerium Wallet
    bytes32 public DOMAIN;

    // The address of the Noir based ZK-SNARK verifier contracts
    address public TxVerifier;
    address public RecoveryVerifier;

    // The hash used as a public inputs for verifiers
    bytes32 private TxHash;
    bytes32 private RecoveryHash;

    // The address of the gas tank contract
    address public GasTank;

    // The public storage of the Valerium Wallet
    bytes public PublicStorage;

    // The nonce for the Valerium Wallet
    uint256 private nonce;

    /**
     * @notice Initializes the Valerium Wallet with the domain and the verifier contracts
     * @dev This method can only be called once.
     *      If the proxy was created without setting up, anyone can call setup and claim the proxy
     * @param _domain The keccak256 hash of the domain of the Valerium Wallet
     * @param _txVerifier The address of the Noir based ZK-SNARK verifier contract for verifying transactions
     * @param _recoveryVerifier The address of the Noir based ZK-SNARK verifier contract for executing recovery transactions
     * @param _forwarder The address of the trusted forwarder (ERC2771)
     * @param _gasTank The address of the gas tank contract
     * @param _txHash The hash used as a public input for the transaction verifier
     * @param _recoveryHash The hash used as a public input for the recovery verifier
     * @param _publicStorage The public storage of the Valerium Wallet
     */
    function setupValerium (
        bytes32 _domain,
        address _txVerifier,
        address _recoveryVerifier,
        address _forwarder,
        address _gasTank,
        bytes32 _txHash,
        bytes32 _recoveryHash,
        bytes memory _publicStorage
    ) external {
        // Checking if the contract is already initialized
        require(DOMAIN == bytes32(0), "Valerium: already initialized");
        require(TxVerifier == address(0), "Valerium: already initialized");
        require(RecoveryVerifier == address(0), "Valerium: already initialized");
        require(GasTank == address(0), "Valerium: already initialized");

        // Setting up the trusted forwarder
        setupTrustedForwarder(_forwarder);
        DOMAIN = _domain;
        TxVerifier = _txVerifier;
        RecoveryVerifier = _recoveryVerifier;
        GasTank = _gasTank;
        TxHash = _txHash;
        RecoveryHash = _recoveryHash;
        PublicStorage = _publicStorage;
    }

    /**
     * @notice Executes a transaction with provided parameters
     * @param _proof The proof input
     * @param to The address of the receiver
     * @param value The amount of Ether to send
     * @param data The data payload
     * @return success boolean flag indicating if the call succeeded
     */
    function executeTx (bytes calldata _proof, address to, uint256 value, bytes calldata data) public payable notTrustedForwarder returns(bool success) {
        // Verifying the proof
        require(verify(_proof, _useNonce(), TxHash, TxVerifier), "Valerium: invalid proof");
        // Executing the transaction
        success = execute(to, value, data, gasleft());
    }
    
    /**
     * @notice Executes a batch of transactions with provided parameters
     * @param _proof The proof input
     * @param to Array of destination addresses
     * @param value Array of Ether values
     * @param data Array of data payloads
     */
    function executeBatchTx (bytes calldata _proof, address[] calldata to, uint256[] calldata value, bytes[] calldata data) public payable notTrustedForwarder {
        // Verifying the proof
        require(verify(_proof, _useNonce(), TxHash, TxVerifier), "Valerium: invalid proof");
        // Executing the batch transactions
        batchExecute(to, value, data);
    }

    /**
     * @notice Executes a recovery transaction to change the transaction hash, transaction verifier and public storage
     * @param _proof The proof input
     * @param _newTxHash The new transaction hash
     * @param _newTxVerifier The address of the new transaction verifier
     * @param _publicStorage The new public storage
     */
    function executeRecovery(bytes calldata _proof, bytes32 _newTxHash, address _newTxVerifier, bytes calldata _publicStorage) public payable notTrustedForwarder {
        // Verifying the proof
        require(verify(_proof, _useNonce(), RecoveryHash, RecoveryVerifier), "Valerium: invalid proof");
        // Updating the Tx Hash, Tx Verifier and Public Storage
        TxHash = _newTxHash;
        TxVerifier = _newTxVerifier;
        PublicStorage = _publicStorage;
    }   

    /**
     * @notice Executes a recovery transaction to change the recovery hash, recovery verifier and public storage
     * @param _proof The proof input
     * @param _newRecoveryHash The new recovery hash
     * @param _newRecoveryVerifier The address of the new recovery verifier
     * @param _publicStorage The new public storage
     */
    function ChangeRecovery(bytes calldata _proof, bytes32 _newRecoveryHash, address _newRecoveryVerifier, bytes calldata _publicStorage) public payable notTrustedForwarder {
        // Verifying the proof
        require(verify(_proof, _useNonce(), RecoveryHash, RecoveryVerifier), "Valerium: invalid proof");
        // Updating the Recovery Hash, Recovery Verifier and Public Storage
        RecoveryHash = _newRecoveryHash;
        RecoveryVerifier = _newRecoveryVerifier;
        PublicStorage = _publicStorage;
    }

    /**
     * @notice Executes a transaction with provided parameters using the trusted forwarder
     * @param _proof The proof input
     * @param to The address of the receiver
     * @param value The amount of Ether to send
     * @param data The data payload
     * @param gasPrice The gas price
     * @param baseGas The base gas
     * @param estimatedFees The estimated fees
     * @return success boolean flag indicating if the call succeeded
     */
    function executeTxWithForwarder(bytes calldata _proof, address to, uint256 value, bytes calldata data, uint256 gasPrice, uint256 baseGas, uint256 estimatedFees) public payable onlyTrustedForwarder returns(bool success) {
        // Checking if the Valerium Wallet has sufficient balance
        require(address(this).balance + value >= estimatedFees, "Valerium: insufficient balance");

        uint256 startGas = gasleft();
        // Verifying the proof
        require(verify(_proof, _useNonce(), TxHash, TxVerifier), "Valerium: invalid proof");
        // Executing the transaction
        success = execute(to, value, data, gasleft());

        // Deducting gas fees from the user's Valerium Wallet
        uint256 gasUsed = startGas - gasleft();
        uint256 gasFee = (gasUsed + baseGas) * gasPrice;
        execute(GasTank, gasFee, "", gasleft());
    }

    /**
     * @notice Executes a batch of transactions with provided parameters using the trusted forwarder
     * @param _proof The proof input
     * @param to Array of destination addresses
     * @param value Array of Ether values
     * @param data Array of data payloads
     * @param gasPrice The gas price
     * @param baseGas The base gas
     * @param estimatedFees The estimated fees
     */
    function executeBatchTxWithForwarder(bytes calldata _proof, address[] calldata to, uint256[] calldata value, bytes[] calldata data, uint256 gasPrice, uint256 baseGas, uint256 estimatedFees) public payable onlyTrustedForwarder {
        // Calculating the total value of the batch transactions
        uint256 totalValue = 0;
        for (uint i = 0; i < value.length; i++) {
            totalValue += value[i];
        }
        // Checking if the Valerium Wallet has sufficient balance
        require(address(this).balance + totalValue >= estimatedFees, "Valerium: insufficient balance");

        uint256 startGas = gasleft();
        // Verifying the proof
        require(verify(_proof, _useNonce(), TxHash, TxVerifier), "Valerium: invalid proof");
        // Executing the batch transactions
        batchExecute(to, value, data);

        // Deducting gas fees from the user's Valerium Wallet
        uint256 gasUsed = startGas - gasleft();
        uint256 gasFee = (gasUsed + baseGas) * gasPrice;
        execute(GasTank, gasFee, "", gasleft());
    }

    /**
     * @notice Executes a recovery transaction to change the transaction hash, transaction verifier and public storage using the trusted forwarder
     * @param _proof The proof input
     * @param _newTxHash The new transaction hash
     * @param _newTxVerifier The address of the new transaction verifier
     * @param _publicStorage The new public storage
     * @param gasPrice The gas price
     * @param baseGas The base gas
     * @param estimatedFees The estimated fees
     */
    function executeRecoveryWithForwarder(bytes calldata _proof, bytes32 _newTxHash, address _newTxVerifier, bytes calldata _publicStorage, uint256 gasPrice, uint256 baseGas, uint256 estimatedFees) public payable onlyTrustedForwarder {
        // Checking if the Valerium Wallet has sufficient balance
        require(address(this).balance >= estimatedFees, "Valerium: insufficient balance");

        uint256 startGas = gasleft();
        // Verifying the proof
        require(verify(_proof, _useNonce(), RecoveryHash, RecoveryVerifier), "Valerium: invalid proof");
        // Updating the Tx Hash, Tx Verifier and Public Storage
        TxHash = _newTxHash;
        TxVerifier = _newTxVerifier;
        PublicStorage = _publicStorage;

        // Deducting gas fees from the user's Valerium Wallet
        uint256 gasUsed = startGas - gasleft();
        uint256 gasFee = (gasUsed + baseGas) * gasPrice;
        execute(GasTank, gasFee, "", gasleft());
    }

    /**
     * @notice Executes a recovery transaction to change the recovery hash, recovery verifier and public storage using the trusted forwarder
     * @param _proof The proof input
     * @param _newRecoveryHash The new recovery hash
     * @param _newRecoveryVerifier The address of the new recovery verifier
     * @param _publicStorage The new public storage
     * @param gasPrice The gas price
     * @param baseGas The base gas
     * @param estimatedFees The estimated fees
     */
    function ChangeRecoveryWithForwarder(bytes calldata _proof, bytes32 _newRecoveryHash, address _newRecoveryVerifier, bytes calldata _publicStorage, uint256 gasPrice, uint256 baseGas, uint256 estimatedFees) public payable onlyTrustedForwarder {
        // Checking if the Valerium Wallet has sufficient balance
        require(address(this).balance >= estimatedFees, "Valerium: insufficient balance");

        uint256 startGas = gasleft();
        // Verifying the proof
        require(verify(_proof, _useNonce(), RecoveryHash, RecoveryVerifier), "Valerium: invalid proof");
        // Updating the Recovery Hash, Recovery Verifier and Public Storage
        RecoveryHash = _newRecoveryHash;
        RecoveryVerifier = _newRecoveryVerifier;
        PublicStorage = _publicStorage;

        // Deducting gas fees from the user's Valerium Wallet
        uint256 gasUsed = startGas - gasleft();
        uint256 gasFee = (gasUsed + baseGas) * gasPrice;
        execute(GasTank, gasFee, "", gasleft());
    }

    /**
     * @notice Returns the nonce of the Valerium Wallet
     * @return The nonce
     */
    function getNonce() public view returns (uint256) {
        return nonce;
    }

    /**
     * @notice Returns the nonce of the Valerium Wallet but increments it for the next use
     * @return The nonce
     */
    function _useNonce() internal returns (uint256) {
        unchecked {
            return nonce++;
        }
    }
}
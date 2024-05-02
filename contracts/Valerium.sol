// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

import "./common/Singleton.sol";
import "./common/StorageAccessible.sol";
import "./base/Executor.sol";
import "./base/ProofManager.sol";
import "./handler/TokenCallbackHandler.sol";
import "./external/Valerium2771Context.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./base/LogManager.sol";

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
 * @notice WARNING : The transactions will not fail if valid proof is given to avoid replay attacks
 * @author Anoy Roy Chowdhury - <anoyroyc3545@gmail.com>
 */

contract Valerium is
    Singleton,
    StorageAccessible,
    Executor,
    ProofManager,
    TokenCallbackHandler,
    Valerium2771Context
{
    string public constant VERSION = "1.0.0";

    // The domain of the Valerium Wallet
    bytes32 public DOMAIN;

    // The address of the Noir based ZK-SNARK verifier contracts
    address public TxVerifier;
    address public RecoveryVerifier;

    // The hash used as a public inputs for verifiers
    bytes32 public TxHash;
    bytes32 public RecoveryHash;

    // The address of the gas tank contract
    address public GasTank;

    // The public storage of the Valerium Wallet
    bytes public PublicStorage;

    // The nonce for the Valerium Wallet
    uint256 private nonce;

    event SetupValerium(
        bytes32 domain,
        address txVerifier,
        address recoveryVerifier,
        address forwarder,
        address gasTank,
        bytes32 txHash,
        bytes32 recoveryHash,
        bytes publicStorage
    );

    event ExecutionResult(
        bytes4 magicValue
    );

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

        emit SetupValerium(
            _domain,
            _txVerifier,
            _recoveryVerifier,
            _forwarder,
            _gasTank,
            _txHash,
            _recoveryHash,
            _publicStorage
        );
    }

    /**
     * @notice Executes a transaction with provided parameters
     * @param _proof The proof input
     * @param to The address of the receiver
     * @param value The amount of Ether to send
     * @param data The data payload
     * @return magicValue bytes4 indicating the status of the execution
     */
    function executeTx (
        bytes calldata _proof, 
        address to, 
        uint256 value, 
        bytes calldata data
        ) public payable notTrustedForwarder returns(bytes4) {
        // Verifying the proof
        if(!verify(_proof, _useNonce(), TxHash, TxVerifier)){
            emit ExecutionResult(INVALID_PROOF);
            return INVALID_PROOF;
        }
        // Executing the transaction
        if(!execute(to, value, data, gasleft())) {
            emit ExecutionResult(UNEXPECTED_ERROR);
            return UNEXPECTED_ERROR;
        }
        emit ExecutionResult(EXECUTION_SUCCESSFUL);
        return EXECUTION_SUCCESSFUL;
    }
    
    /**
     * @notice Executes a batch of transactions with provided parameters
     * @param _proof The proof input
     * @param to Array of destination addresses
     * @param value Array of Ether values
     * @param data Array of data payloads
     * @return magicValue bytes4 indicating the status of the execution
     */
    function executeBatchTx (
        bytes calldata _proof, 
        address[] calldata to, 
        uint256[] calldata value, 
        bytes[] calldata data
        ) public payable notTrustedForwarder returns (bytes4){        
        // Verifying the proof
        if(!verify(_proof, _useNonce(), TxHash, TxVerifier)) {
            emit ExecutionResult(INVALID_PROOF);
            return INVALID_PROOF;
        }
        // Executing the batch transactions
        if(!batchExecute(to, value, data)) {
            emit ExecutionResult(UNEXPECTED_ERROR);
            return UNEXPECTED_ERROR;
        }
        emit ExecutionResult(EXECUTION_SUCCESSFUL);
        return EXECUTION_SUCCESSFUL;
    }

    /**
     * @notice Executes a recovery transaction to change the transaction hash, transaction verifier and public storage
     * @param _proof The proof input
     * @param _newTxHash The new transaction hash
     * @param _newTxVerifier The address of the new transaction verifier
     * @param _publicStorage The new public storage
     * @return magicValue bytes4 indicating the status of the execution
     */
    function executeRecovery(
        bytes calldata _proof, 
        bytes32 _newTxHash, 
        address _newTxVerifier, 
        bytes calldata _publicStorage
        ) public payable notTrustedForwarder returns(bytes4) {
        // Verifying the proof
        if(!verify(_proof, _useNonce(), RecoveryHash, RecoveryVerifier)){
            emit ExecutionResult(INVALID_PROOF);
            return INVALID_PROOF;
        }
        // Updating the Tx Hash, Tx Verifier and Public Storage
        TxHash = _newTxHash;
        TxVerifier = _newTxVerifier;
        PublicStorage = _publicStorage;

        emit ExecutionResult(RECOVERY_SUCCESSFUL);
        return RECOVERY_SUCCESSFUL;
    }   

    /**
     * @notice Executes a recovery transaction to change the recovery hash, recovery verifier and public storage
     * @param _proof The proof input
     * @param _newRecoveryHash The new recovery hash
     * @param _newRecoveryVerifier The address of the new recovery verifier
     * @param _publicStorage The new public storage
     * @return magicValue bytes4 indicating the status of the execution
     */
    function changeRecovery(
        bytes calldata _proof, 
        bytes32 _newRecoveryHash, 
        address _newRecoveryVerifier, 
        bytes calldata _publicStorage
        ) public payable notTrustedForwarder returns (bytes4) {
        // Verifying the proof
        if(!verify(_proof, _useNonce(), RecoveryHash, RecoveryVerifier)){
            emit ExecutionResult(INVALID_PROOF);
            return INVALID_PROOF;
        }
        // Updating the Recovery Hash, Recovery Verifier and Public Storage
        RecoveryHash = _newRecoveryHash;
        RecoveryVerifier = _newRecoveryVerifier;
        PublicStorage = _publicStorage;

        emit ExecutionResult(CHANGE_SUCCESSFUL);
        return CHANGE_SUCCESSFUL;
    }

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
     * @return magicValue bytes4 indicating the status of the execution
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
        ) public payable onlyTrustedForwarder returns(bytes4 magicValue) {
        // Verifying the proof
        if(!verify(_proof, _useNonce(), TxHash, TxVerifier)){
            emit ExecutionResult(INVALID_PROOF);
            return INVALID_PROOF;
        }

        // Checking if the Valerium Wallet has sufficient balance
        if(!checkBalance(token, estimatedFees)){
            emit ExecutionResult(INSUFFICIENT_BALANCE);
            return INSUFFICIENT_BALANCE;
        }

        uint256 startGas = gasleft();

        magicValue = EXECUTION_SUCCESSFUL;

        // Executing the transaction
        if(!execute(to, value, data, gasleft())){
            magicValue = UNEXPECTED_ERROR;
        }

        // Deducting gas fees from the user's Valerium Wallet
        magicValue = chargeFees(startGas, gasPrice, baseGas, GasTank, token, magicValue);
        emit ExecutionResult(magicValue);
    }

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
        ) public payable onlyTrustedForwarder returns(bytes4 magicValue){
        // Verifying the proof
        if(!verify(_proof, _useNonce(), TxHash, TxVerifier)){
            emit ExecutionResult(INVALID_PROOF);
            return INVALID_PROOF;
        }

        // Calculating the total value of the batch transactions
        if (checkBalance(token, estimatedFees) == false) {
            emit ExecutionResult(INSUFFICIENT_BALANCE);
            return INSUFFICIENT_BALANCE;
        }

        uint256 startGas = gasleft();

        magicValue = EXECUTION_SUCCESSFUL;

        // Executing the batch transactions
        if (batchExecute(to, value, data)) {
            magicValue = UNEXPECTED_ERROR;
        }

        // Deducting gas fees from the user's Valerium Wallet
        magicValue = chargeFees(startGas, gasPrice, baseGas, GasTank, token, magicValue);
        emit ExecutionResult(magicValue);
    }

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
        ) public payable onlyTrustedForwarder returns (bytes4 magicValue){
        // Verifying the proof
        if(!verify(_proof, _useNonce(), RecoveryHash, RecoveryVerifier)){
            return INVALID_PROOF;
        }
        
        // Checking if the Valerium Wallet has sufficient balance
        if (!checkBalance(token, estimatedFees)) {
            return INSUFFICIENT_BALANCE;
        }

        uint256 startGas = gasleft();
    
        // Updating the Tx Hash, Tx Verifier and Public Storage
        TxHash = _newTxHash;
        TxVerifier = _newTxVerifier;
        PublicStorage = _publicStorage;

        // Deducting gas fees from the user's Valerium Wallet
        magicValue = chargeFees(startGas, gasPrice, baseGas, GasTank, token, RECOVERY_SUCCESSFUL);
        emit ExecutionResult(magicValue);
    }

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
        ) public payable onlyTrustedForwarder returns (bytes4 magicValue){
        // Verifying the proof
        if(!verify(_proof, _useNonce(), RecoveryHash, RecoveryVerifier)){
            return INVALID_PROOF;
        }
        
        // Checking if the Valerium Wallet has sufficient balance
       if (!checkBalance(token, estimatedFees)) {
            return INSUFFICIENT_BALANCE;
        }

        uint256 startGas = gasleft();
      
        // Updating the Recovery Hash, Recovery Verifier and Public Storage
        RecoveryHash = _newRecoveryHash;
        RecoveryVerifier = _newRecoveryVerifier;
        PublicStorage = _publicStorage;

        // Deducting gas fees from the user's Valerium Wallet
        magicValue = chargeFees(startGas, gasPrice, baseGas, GasTank, token, CHANGE_SUCCESSFUL);
        emit ExecutionResult(magicValue);
    }

    /**
     * @notice Checks if the Valerium Wallet has sufficient balance
     * @param token  The address of the token, if the address is 0x0, it is an Ether transaction
     * @param estimatedFees The estimated fees of the transaction
     */
    function checkBalance(address token, uint256 estimatedFees) public view returns (bool) {
        if(token != address(0)){
            uint8 decimals = IERC20(token).decimals();
            if(IERC20(token).balanceOf(address(this)) < estimatedFees / 10 ** (18 - decimals)){
                return false;
            }
        } else {
            if(address(this).balance < estimatedFees){
                return false;
            }
        }

        return true;
    }


    /**
     * @notice Verifies if the proof is valid or not
     * @dev The parameters are named to maintain the same implementation as EIP-1271
     *      Should return whether the proof provided is valid for the provided data
     * @param _hash the message which is used to verify zero-knowledge proof
     * @param _signature Noir based zero-knowledge proof
     */
    function isValidSignature(
        bytes32 _hash,
        bytes calldata _signature
    ) public view returns (bytes4 magicValue) {
        if(verify(_signature, _hash, TxHash, TxVerifier)){
            return 0x1626ba7e;
        } else {
            return 0xffffffff;
        }
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

    receive() external payable {}

    fallback() external payable {}
}
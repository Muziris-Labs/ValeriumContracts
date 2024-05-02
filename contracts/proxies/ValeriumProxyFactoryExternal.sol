// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

import "./ValeriumProxy.sol";
import "./IProxyCreationCallback.sol";
import "../base/DomainManager.sol";
import "../external/Valerium2771Context.sol";
import "../cross-chain/ProofHandler.sol";
import "../base/Verifier.sol";

/**
 * @title Proxy Factory External - Allows to create a new proxy contract and execute a message call to the new proxy within one transaction.
 * @author Anoy Roy Chowdhury - <anoyroyc3545@gmail.com>
 * @dev DEPRECATED: This contract is deprecated and will be removed in future versions. Use ValeriumProxyFactory instead.
 */
contract ValeriumProxyFactoryExternal is DomainManager, Valerium2771Context, ProofHandler, Verifier {
    event ProxyCreation(ValeriumProxy indexed proxy, address singleton);
    event SingletonUpdated(address singleton);

    // The address of the account that initially created the factory contract.
    address private GenesisAddress;

    // The address of the current singleton contract used as the master copy for proxy contracts.
    address private CurrentSingleton;

    // The address of the server verifier contract.
    address public ServerVerifier;

    // The hash of the server.
    bytes32 private serverHash;

    // The constructor sets the initial singleton contract address, the GenesisAddress, the server verifier and the server hash.
    constructor(address CurrentSingleton_, address _serverVerifier, bytes32 _serverHash) {
        CurrentSingleton = CurrentSingleton_;
        GenesisAddress = msg.sender;

        ServerVerifier = _serverVerifier;
        serverHash = _serverHash;
    }

    /// @dev Allows to retrieve the creation code used for the Proxy deployment. With this it is easily possible to calculate predicted address.
    function proxyCreationCode() public pure returns (bytes memory) {
        return type(ValeriumProxy).creationCode;
    }

    /**
     * @notice Internal method to create a new proxy contract using CREATE2. Optionally executes an initializer call to a new proxy.
     * @dev WARNING : The Transaction will not fail if a valid proof is given for avoid replay attacks.
     * @param initializer (Optional) Payload for a message call to be sent to a new proxy contract.
     * @param salt Create2 salt to use for calculating the address of the new proxy contract.
     * @return proxy Address of the new proxy contract.
     */
    function deployProxy(bytes memory initializer, bytes32 salt) internal returns (ValeriumProxy proxy) {
        if(!isContract(CurrentSingleton)){
            return ValeriumProxy(payable(address(0)));
        }   

        bytes memory deploymentData = abi.encodePacked(type(ValeriumProxy).creationCode, uint256(uint160(CurrentSingleton)));
        // solhint-disable-next-line no-inline-assembly
        assembly {
            proxy := create2(0x0, add(0x20, deploymentData), mload(deploymentData), salt)
        }
        if(address(proxy) == address(0)){
            return ValeriumProxy(payable(address(0)));
        }

        if (initializer.length > 0) {
            // solhint-disable-next-line no-inline-assembly
            assembly {
                if eq(call(gas(), proxy, 0, add(initializer, 0x20), mload(initializer), 0, 0), 0) {
                    proxy := 0
                }
            }
        }
    }

    /**
     * @notice Updates the address of the current singleton contract used as the master copy for proxy contracts.
     * @dev Only the Genesis Address can update the Singleton.
     * @param _singleton Address of the current singleton contract.
     */
    function updateSingleton(address _singleton) external {
        require(msg.sender == GenesisAddress, "Only the Genesis Address can update the Singleton");
        CurrentSingleton = _singleton;
        emit SingletonUpdated(_singleton);
    }

    /**
     * @notice Deploys a new proxy with `_singleton` singleton and `saltNonce` salt. Optionally executes an initializer call to a new proxy.
     * @dev WARNING : The Transaction will not fail if a valid proof is given for avoid replay attacks.
     * @param serverProof Proof that the server has approved the creation of the proxy.
     * @param domain Domain name for the new proxy contract.
     * @param initializer Payload for a message call to be sent to a new proxy contract.
     * @param saltNonce Nonce that will be used to generate the salt to calculate the address of the new proxy contract.
     */
    function createProxyWithNonce(bytes calldata serverProof, string memory domain, bytes memory initializer, uint256 saltNonce) public returns (ValeriumProxy proxy) {
        // Check for Valid Server Proof
        require(verify(serverProof, serverHash, ServerVerifier, bytes4(keccak256(abi.encodePacked(domain)))), "Invalid server proof");

        // Check if the domain already exists
        if(domainExists(domain)){
            return ValeriumProxy(payable(address(0)));
        }

        // If the initializer or domain changes the proxy address should change too. Hashing the initializer data is cheaper than just concatinating it
        bytes32 salt = keccak256(abi.encodePacked(keccak256(abi.encodePacked(domain)), keccak256(initializer), saltNonce));
        proxy = deployProxy(initializer, salt);

        if(address(proxy) == address(0)){
            return ValeriumProxy(payable(address(0)));
        }

        addDomain(domain, address(proxy));
        emit ProxyCreation(proxy, CurrentSingleton);
    }

    /**
     * @notice Deploys a new chain-specific proxy with `_singleton` singleton and `saltNonce` salt. Optionally executes an initializer call to a new proxy.
     * @dev Allows to create a new proxy contract that should exist only on 1 network (e.g. specific governance or admin accounts)
     *      by including the chain id in the create2 salt. Such proxies cannot be created on other networks by replaying the transaction.
     *      WARNING : The Transaction will not fail if a valid proof is given for avoid replay attacks.
     * @param serverProof Proof that the server has approved the creation of the proxy.
     * @param domain Domain name for the new proxy contract.
     * @param initializer Payload for a message call to be sent to a new proxy contract.
     * @param saltNonce Nonce that will be used to generate the salt to calculate the address of the new proxy contract.
     */
    function createChainSpecificProxyWithNonce(
        bytes calldata serverProof,
        string memory domain,
        bytes memory initializer,
        uint256 saltNonce
    ) public returns (ValeriumProxy proxy) {
        // Check for Valid Server Proof
        require(verify(serverProof, serverHash, ServerVerifier, bytes4(keccak256(abi.encodePacked(domain)))), "Invalid server proof");

        // Check if the domain already exists
        if(domainExists(domain)){
            return ValeriumProxy(payable(address(0)));
        }

        // If the initializer or domain changes the proxy address should change too. Hashing the initializer data is cheaper than just concatinating it
        bytes32 salt = keccak256(abi.encodePacked(keccak256(abi.encodePacked(domain)), keccak256(initializer), saltNonce, getChainId()));
        proxy = deployProxy(initializer, salt);

        if(address(proxy) == address(0)){
            return ValeriumProxy(payable(address(0)));
        }

        addDomain(domain, address(proxy));
        emit ProxyCreation(proxy, CurrentSingleton);
    }

    /**
     * @notice Deploy a new proxy with `_singleton` singleton and `saltNonce` salt.
     *         Optionally executes an initializer call to a new proxy and calls a specified callback address `callback`.
     * @param serverProof Proof that the server has approved the creation of the proxy.
     * @param domain Domain name for the new proxy contract.
     * @param initializer Payload for a message call to be sent to a new proxy contract.
     * @param saltNonce Nonce that will be used to generate the salt to calculate the address of the new proxy contract.
     * @param callback Callback that will be invoked after the new proxy contract has been successfully deployed and initialized.
     */
    function createProxyWithCallback(
        bytes calldata serverProof,
        string memory domain,
        bytes memory initializer,
        uint256 saltNonce,
        IProxyCreationCallback callback
    ) public returns (ValeriumProxy proxy) {
        uint256 saltNonceWithCallback = uint256(keccak256(abi.encodePacked(saltNonce, callback)));
        proxy = createProxyWithNonce(serverProof, domain, initializer, saltNonceWithCallback);
        if (address(callback) != address(0)) callback.proxyCreated(proxy, CurrentSingleton, initializer, saltNonce);
    }

    /**
     * @notice Verifies the proof and returns the result of verification.
     * @param _proof The proof inputs
     * @param _serverHash The server hash
     * @param _verifier The address of the verifier contract
     */
    function verify(
        bytes calldata _proof,
        bytes32 _serverHash,
        address _verifier,
        bytes4 _domain
    ) internal returns (bool) {
        bytes32[] memory publicInputs;
        
        require(isProofDuplicate(_proof) == false, "Proof already exists");

        // Add the proof to prevent reuse
        addProof(_proof);

        // Use scope here to limit variable lifetime and prevent `stack too deep` errors
        {
            publicInputs = new bytes32[](3);
            publicInputs[0] = _serverHash;
            publicInputs[1] = bytes32(uint256(uint32(_domain)));
            publicInputs[2] = bytes32(getChainId());
        }
       
        return verifyProof(_proof, publicInputs, _verifier);
    }

    /**
     * @notice Returns true if `account` is a contract.
     * @dev This function will return false if invoked during the constructor of a contract,
     *      as the code is not actually created until after the constructor finishes.
     * @param account The address being queried
     * @return True if `account` is a contract
     */
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    /**
     * @notice Returns the ID of the chain the contract is currently deployed on.
     * @return The ID of the current chain as a uint256.
     */
    function getChainId() public view returns (uint256) {
        uint256 id;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            id := chainid()
        }
        return id;
    }

    /**
     * @notice Allows the Genesis Address to setup the forwarder.
     * @param forwarder Address of the forwarder contract.
     */
    function setupForwarder(address forwarder) public {
        require(msg.sender == GenesisAddress, "Only the Genesis Address can setup the forwarder");
        setupTrustedForwarder(forwarder);
    }

    /**
     * @notice Allows the Genesis Address to transfer ownership.
     * @param newGenesis Address of the new Genesis Address.
     */
    function transferGenesis(address newGenesis) external {
        require(msg.sender == GenesisAddress, "Only the Genesis Address can transfer ownership");
        GenesisAddress = newGenesis;
    }

    /**
     * @notice Allows the Genesis Address to change server properties.
     * @param _serverVerifier Address of the server verifier contract.
     * @param _serverHash Hash of the server.
     */
    function changeServerProps(address _serverVerifier, bytes32 _serverHash) external {
        require(msg.sender == GenesisAddress, "Only the Genesis Address can change server properties");
        ServerVerifier = _serverVerifier;
        serverHash = _serverHash;
    }
}

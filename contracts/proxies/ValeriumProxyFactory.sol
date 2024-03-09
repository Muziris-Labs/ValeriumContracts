// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

import "./ValeriumProxy.sol";
import "./IProxyCreationCallback.sol";
import "../base/DomainManager.sol";
import "../external/ERC2771Context.sol";

/**
 * @title Proxy Factory - Allows to create a new proxy contract and execute a message call to the new proxy within one transaction.
 * @author Stefan George - @Georgi87
 * @author Anoy Roy Chowdhury - <anoyroyc3545@gmail.com>
 */
contract ValeriumProxyFactory is DomainManager, ERC2771Context {
    event ProxyCreation(ValeriumProxy indexed proxy, address singleton);
    event SingletonUpdated(address singleton);

    // The address of the account that initially created the factory contract.
    address private GenesisAddress;

    // The address of the current singleton contract used as the master copy for proxy contracts.
    address private CurrentSingleton;

    // The constructor sets the initial singleton contract address and the GenesisAddress.
    constructor(address CurrentSingleton_) {
        CurrentSingleton = CurrentSingleton_;
        GenesisAddress = msg.sender;
    }

    /// @dev Allows to retrieve the creation code used for the Proxy deployment. With this it is easily possible to calculate predicted address.
    function proxyCreationCode() public pure returns (bytes memory) {
        return type(ValeriumProxy).creationCode;
    }

    /**
     * @notice Internal method to create a new proxy contract using CREATE2. Optionally executes an initializer call to a new proxy.
     * @param initializer (Optional) Payload for a message call to be sent to a new proxy contract.
     * @param salt Create2 salt to use for calculating the address of the new proxy contract.
     * @return proxy Address of the new proxy contract.
     */
    function deployProxy(bytes memory initializer, bytes32 salt) internal returns (ValeriumProxy proxy) {
        require(isContract(CurrentSingleton), "Singleton contract not deployed");

        bytes memory deploymentData = abi.encodePacked(type(ValeriumProxy).creationCode, uint256(uint160(CurrentSingleton)));
        // solhint-disable-next-line no-inline-assembly
        assembly {
            proxy := create2(0x0, add(0x20, deploymentData), mload(deploymentData), salt)
        }
        require(address(proxy) != address(0), "Create2 call failed");

        if (initializer.length > 0) {
            // solhint-disable-next-line no-inline-assembly
            assembly {
                if eq(call(gas(), proxy, 0, add(initializer, 0x20), mload(initializer), 0, 0), 0) {
                    revert(0, 0)
                }
            }
        }
    }

    /**
     * @notice Updates the address of the current singleton contract used as the master copy for proxy contracts.
     * @dev Only the Genesis Address can update the Singleton.
     * @param _singleton Address of the current singleton contract.
     */
    function updateSingleton(address _singleton) public {
        require(msg.sender == GenesisAddress, "Only the Genesis Address can update the Singleton");
        CurrentSingleton = _singleton;
        emit SingletonUpdated(_singleton);
    }

    /**
     * @notice Deploys a new proxy with `_singleton` singleton and `saltNonce` salt. Optionally executes an initializer call to a new proxy.
     * @param initializer Payload for a message call to be sent to a new proxy contract.
     * @param saltNonce Nonce that will be used to generate the salt to calculate the address of the new proxy contract.
     */
    function createProxyWithNonce(string memory domain, bytes memory initializer, uint256 saltNonce) public returns (ValeriumProxy proxy) {
        // Check if the domain already exists
        require(!domainExists(domain), "Domain already exists");

        // If the initializer or domain changes the proxy address should change too. Hashing the initializer data is cheaper than just concatinating it
        bytes32 salt = keccak256(abi.encodePacked(keccak256(abi.encodePacked(domain)), keccak256(initializer), saltNonce));
        proxy = deployProxy(initializer, salt);
        addDomain(domain, address(proxy));
        emit ProxyCreation(proxy, CurrentSingleton);
    }

    /**
     * @notice Deploys a new chain-specific proxy with `_singleton` singleton and `saltNonce` salt. Optionally executes an initializer call to a new proxy.
     * @dev Allows to create a new proxy contract that should exist only on 1 network (e.g. specific governance or admin accounts)
     *      by including the chain id in the create2 salt. Such proxies cannot be created on other networks by replaying the transaction.
     * @param initializer Payload for a message call to be sent to a new proxy contract.
     * @param saltNonce Nonce that will be used to generate the salt to calculate the address of the new proxy contract.
     */
    function createChainSpecificProxyWithNonce(
        string memory domain,
        bytes memory initializer,
        uint256 saltNonce
    ) public returns (ValeriumProxy proxy) {
        // Check if the domain already exists
        require(!domainExists(domain), "Domain already exists");

        // If the initializer or domain changes the proxy address should change too. Hashing the initializer data is cheaper than just concatinating it
        bytes32 salt = keccak256(abi.encodePacked(keccak256(abi.encodePacked(domain)), keccak256(initializer), saltNonce, getChainId()));
        proxy = deployProxy(initializer, salt);
        addDomain(domain, address(proxy));
        emit ProxyCreation(proxy, CurrentSingleton);
    }

    /**
     * @notice Deploy a new proxy with `_singleton` singleton and `saltNonce` salt.
     *         Optionally executes an initializer call to a new proxy and calls a specified callback address `callback`.
     * @param initializer Payload for a message call to be sent to a new proxy contract.
     * @param saltNonce Nonce that will be used to generate the salt to calculate the address of the new proxy contract.
     * @param callback Callback that will be invoked after the new proxy contract has been successfully deployed and initialized.
     */
    function createProxyWithCallback(
        string memory domain,
        bytes memory initializer,
        uint256 saltNonce,
        IProxyCreationCallback callback
    ) public returns (ValeriumProxy proxy) {
        uint256 saltNonceWithCallback = uint256(keccak256(abi.encodePacked(saltNonce, callback)));
        proxy = createProxyWithNonce(domain, initializer, saltNonceWithCallback);
        if (address(callback) != address(0)) callback.proxyCreated(proxy, CurrentSingleton, initializer, saltNonce);
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
}

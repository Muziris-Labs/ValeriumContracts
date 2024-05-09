// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

import "./ValeriumProxy.sol";
import "./IProxyCreationCallback.sol";
import "../external/Valerium2771Context.sol";
import "../cross-chain/ProofHandler.sol";
import "../base/Verifier.sol";

/**
 * @title Proxy Factory - Allows to create a new proxy contract and execute a message call to the new proxy within one transaction.
 * @author Anoy Roy Chowdhury - <anoyroyc3545@gmail.com>
 */
contract ValeriumProxyFactory is Valerium2771Context, ProofHandler, Verifier {
    event ProxyCreation(ValeriumProxy indexed proxy, address singleton);
    event SingletonUpdated(address singleton);

    // The address of the account that initially created the factory contract.
    address private GenesisAddress;

    // The address of the current singleton contract used as the master copy for proxy contracts.
    address private CurrentSingleton;

    // Is the contract deployed on the base chain.
    bool immutable IsBaseChain;

    // The constructor sets the initial singleton contract address and the GenesisAddress.
    constructor(address CurrentSingleton_, bool _isBaseChain) {
        CurrentSingleton = CurrentSingleton_;
        GenesisAddress = msg.sender;
        IsBaseChain = _isBaseChain;
    }

    /**
     * @notice  Modifier to restrict the execution of a function to the base chain. If the contract is not deployed on the base chain, the function can only be called by the trusted forwarder.
     */
    modifier checkBase {
        if (!IsBaseChain) {
            require(msg.sender == trustedForwarder(), "Only the trusted forwarder can call this function");
        }
        _;
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
    function updateSingleton(address _singleton) external {
        require(msg.sender == GenesisAddress, "Only the Genesis Address can update the Singleton");
        CurrentSingleton = _singleton;
        emit SingletonUpdated(_singleton);
    }

    /**
     * @notice Deploys a new proxy with `_singleton` singleton. Optionally executes an initializer call to a new proxy.
     * @param domain The domain name of the new proxy contract.
     * @param initializer Payload for a message call to be sent to a new proxy contract.
     * @dev The domain name is used to calculate the salt for the CREATE2 call.
     */
    function createProxyWithDomain(string memory domain, bytes memory initializer) checkBase public returns (ValeriumProxy proxy) {
        // If the domain changes the proxy address should change too. 
        bytes32 salt = keccak256(abi.encodePacked(keccak256(abi.encodePacked(domain))));
        proxy = deployProxy(initializer, salt);

        emit ProxyCreation(proxy, CurrentSingleton);
    }

    /**
     * @notice Deploy a new proxy with `_singleton` singleton
     *         Optionally executes an initializer call to a new proxy and calls a specified callback address `callback`.
     * @param domain The domain name of the new proxy contract.
     * @param initializer Payload for a message call to be sent to a new proxy contract.
     * @param callback Callback that will be invoked after the new proxy contract has been successfully deployed and initialized.
     * @dev The domain name is used to calculate the salt for the CREATE2 call.
     */
    function createProxyWithCallback(
        string memory domain,
        bytes memory initializer,
        IProxyCreationCallback callback
    ) checkBase public returns (ValeriumProxy proxy) {
        proxy = createProxyWithDomain(domain, initializer);
        if (address(callback) != address(0)) callback.proxyCreated(proxy, CurrentSingleton, initializer);
    }

     /**
     * @notice Retrieves the ValeriumProxy contract address for a given domain.
     * @param domain Domain name.
     * @return valeriumProxy ValeriumProxy contract address.
     */
    function getValeriumProxy(string memory domain) public view returns (address valeriumProxy) {
        bytes32 salt = keccak256(abi.encodePacked(keccak256(abi.encodePacked(domain))));
        bytes memory deploymentData = abi.encodePacked(proxyCreationCode(), uint256(uint160(CurrentSingleton)));

        // Calculate the address of the proxy contract using CREATE2
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                salt,
                keccak256(deploymentData)
            )
        );

        // Cast the hash to an address
        address valerium = address(uint160(uint256(hash)));

        if (isContract(valerium)) {
            return valerium;
        } else {
            return address(0);
        }
    }

    /**
     * @notice Checks if a domain exists.
     * @param domain Domain name.
     * @return exists Boolean value indicating if the domain exists.
     */
    function domainExists(string memory domain) public view returns (bool exists) {
        return getValeriumProxy(domain) != address(0);
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
}

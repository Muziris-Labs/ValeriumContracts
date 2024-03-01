// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

/**
 * @title Domain Manager - Manages Domain and its ValeriumProxy Contract.
 * @dev Uses a map to store the domain on-chain and its corresponding ValeriumProxy contract.
 * @author Anoy Roy Chowdhury - <anoyroyc3545@gmail.com>
 */

abstract contract DomainManager {
    event AddedDomain(bytes32 indexed domain, address indexed valeriumProxy);

    mapping (bytes32 => address) internal Domains;

    /**
     * @notice Adds a domain and its corresponding ValeriumProxy contract.
     * @param domain Domain name.
     * @param valeriumProxy ValeriumProxy contract address.
     */
    function addDomain(string memory domain, address valeriumProxy) internal {
        // Check if the valeriumProxy address is valid
        require(valeriumProxy != address(0), "Invalid valeriumProxy address provided");
        // Check if the domain already exists
        require(Domains[keccak256(abi.encodePacked(domain))] == address(0), "Domain already exists");

        // Keccak256 hash of the domain is used as the key to store the valeriumProxy address
        bytes32 domainHash = keccak256(abi.encodePacked(domain));
        // Store the domain and its corresponding valeriumProxy address
        Domains[domainHash] = valeriumProxy;
        
        emit AddedDomain(domainHash, valeriumProxy);
    }

    /**
     * @notice Retrieves the ValeriumProxy contract address for a given domain.
     * @param domain Domain name.
     * @return valeriumProxy ValeriumProxy contract address.
     */
    function getValeriumProxy(string memory domain) public view returns (address valeriumProxy) {
        // Keccak256 hash of the domain is used as the key to retrieve the valeriumProxy address
        valeriumProxy = Domains[keccak256(abi.encodePacked(domain))];
        require(valeriumProxy != address(0), "Domain does not exist");

        return valeriumProxy;
    }

    /**
     * @notice Checks if a domain exists.
     * @param domain Domain name.
     * @return exists Boolean value indicating if the domain exists.
     */

    function domainExists(string memory domain) public view returns (bool exists) {
        // Keccak256 hash of the domain is used as the key to check if the domain exists
        exists = Domains[keccak256(abi.encodePacked(domain))] != address(0);
        return exists;
    }
}
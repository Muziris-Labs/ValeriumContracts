// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.1) (metatx/ERC2771Context.sol)

pragma solidity ^0.8.20;

import {Context} from "./Context.sol";

/**
 * @dev Context variant with ERC-2771 support. This version of the context is used to support the Valerium Wallet.
 * @author Anoy Roy Chowdhury - <anoyroyc3545@gmail.com>
 *
 * WARNING: Avoid using this pattern in contracts that rely in a specific calldata length as they'll
 * be affected by any forwarder whose `msg.data` is suffixed with the `from` address according to the ERC-2771
 * specification adding the address size in bytes (20) to the calldata size. An example of an unexpected
 * behavior could be an unintended fallback (or another function) invocation while trying to invoke the `receive`
 * function only accessible if `msg.data.length == 0`.
 *
 * WARNING: The usage of `delegatecall` in this contract is dangerous and may result in context corruption.
 * Any forwarded request to this contract triggering a `delegatecall` to itself will result in an invalid {_msgSender}
 * recovery.
 */
abstract contract ERC2771Context is Context {
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address private _trustedForwarder;

    /**
     * @notice Sets the trusted forwarder for the context, could be called only once.
     * @param forwarder The forwarder to be trusted
     */
    function setupTrustedForwarder(address forwarder) internal {
        // Checking if the forwarder is already set
        require(_trustedForwarder == address(0), "ERC2771Context: forwarder already set");
        // Checking if the forwarder address is not zero
        require(forwarder != address(0), "ERC2771Context: invalid trusted forwarder");
        _trustedForwarder = forwarder;
    }
   
    /**
     * @dev Returns the address of the trusted forwarder.
     */
    function trustedForwarder() public view virtual returns (address) {
        return _trustedForwarder;
    }

    /**
     * @dev Indicates whether any particular address is the trusted forwarder.
     */
    function isTrustedForwarder(address forwarder) public view virtual returns (bool) {
        return forwarder == trustedForwarder();
    }

    /**
     * @dev Modifier to check if the caller is the trusted forwarder.
     */
    modifier onlyTrustedForwarder() {
        require(isTrustedForwarder(msg.sender), "ERC2771Context: caller is not the trusted forwarder");
        _;
    }

    modifier notTrustedForwarder() {
        require(!isTrustedForwarder(msg.sender), "ERC2771Context: caller is the trusted forwarder");
        _;
    }

    /**
     * @dev Override for `msg.sender`. Defaults to the original `msg.sender` whenever
     * a call is not performed by the trusted forwarder or the calldata length is less than
     * 20 bytes (an address length).
     */
    function _msgSender() internal view virtual override returns (address) {
        uint256 calldataLength = msg.data.length;
        uint256 contextSuffixLength = _contextSuffixLength();
        if (isTrustedForwarder(msg.sender) && calldataLength >= contextSuffixLength) {
            return address(bytes20(msg.data[calldataLength - contextSuffixLength:]));
        } else {
            return super._msgSender();
        }
    }

    /**
     * @dev Override for `msg.data`. Defaults to the original `msg.data` whenever
     * a call is not performed by the trusted forwarder or the calldata length is less than
     * 20 bytes (an address length).
     */
    function _msgData() internal view virtual override returns (bytes calldata) {
        uint256 calldataLength = msg.data.length;
        uint256 contextSuffixLength = _contextSuffixLength();
        if (isTrustedForwarder(msg.sender) && calldataLength >= contextSuffixLength) {
            return msg.data[:calldataLength - contextSuffixLength];
        } else {
            return super._msgData();
        }
    }

    /**
     * @dev ERC-2771 specifies the context as being a single address (20 bytes).
     */
    function _contextSuffixLength() internal view virtual override returns (uint256) {
        return 20;
    }
}
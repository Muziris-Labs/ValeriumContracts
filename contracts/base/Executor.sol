// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

/**
 * @title Executor - A contract that can execute transactions
 * @author Anoy Roy Chowdhury - <anoyroyc3545@gmail.com>
 */
abstract contract Executor {
    /**
     * @notice Executes a call with provided parameters.
     * @dev This method doesn't perform any sanity check of the transaction, such as:
     *      - if the contract at `to` address has code or not
     *      It is the responsibility of the caller to perform such checks.
     * @param to Destination address.
     * @param value Ether value.
     * @param data Data payload.
     * @return success boolean flag indicating if the call succeeded.
     */
    function execute(
        address to,
        uint256 value,
        bytes memory data,
        uint256 txGas
    ) internal returns (bool success) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            success := call(txGas, to, value, add(data, 0x20), mload(data), 0, 0)
        } 
    }

    /**
     * @notice Executes a batch of calls with provided parameters.
     * @dev This method doesn't perform any sanity check of the transactions, such as:
     *      - if the contract at `to` address has code or not
     *      It is the responsibility of the caller to perform such checks.
     * @param to Array of destination addresses.
     * @param value Array of Ether values.
     * @param data Array of data payloads.
     */
    function batchExecute(address[] calldata to, uint256[] calldata value, bytes[] calldata data) internal {
        // Check if the 'to' and 'data' arrays have the same length, and if 'value' array is either empty or has the same length as 'data'
        require(to.length == data.length && (value.length == 0 || value.length == data.length), "wrong array lengths");

        // Start of assembly block
        assembly {
            // Load the length of the 'to' array
            let len := calldataload(to.offset)
            // Load the length of the 'value' array
            let valueLen := calldataload(value.offset)

            // Start of for loop that iterates over the 'to' array
            for { let i := 0 } lt(i, len) { i := add(i, 1) } {
                // Load the 'to' address for the current iteration
                let toAddr := calldataload(add(add(to.offset, 0x20), mul(i, 0x20)))
                // Initialize the 'value' amount to 0
                let valueAmount := 0
                // If 'value' array is not empty, load the 'value' amount for the current iteration
                if valueLen {
                    valueAmount := calldataload(add(add(value.offset, 0x20), mul(i, 0x20)))
                }
                // Load the offset of the 'data' for the current iteration
                let dataOffset := calldataload(add(add(data.offset, 0x20), mul(i, 0x20)))
                // Load the length of the 'data' for the current iteration
                let dataLength := calldataload(dataOffset)
                // Calculate the start of the 'data' for the current iteration
                let dataStart := add(dataOffset, 0x20)

                // Execute the call and store the success status
                let success := call(gas(), toAddr, valueAmount, dataStart, dataLength, 0, 0)
                // If the call was not successful, revert the transaction
                if iszero(success) {
                    revert(0, 0)
                }
            }
        }
    }
}

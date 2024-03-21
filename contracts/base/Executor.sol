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
     * @param tos Array of destination addresses.
     * @param values Array of Ether values.
     * @param datas Array of data payloads.
     */
    function batchExecute(address[] memory tos, uint256[] memory values, bytes[] memory datas) internal returns (bool success){
        // Ensure that the lengths of the 'tos', 'values', and 'datas' arrays are all the same
        require(tos.length == values.length && tos.length == datas.length, "Array lengths must match");

        // Iterate over the 'tos' array
        for (uint i = 0; i < tos.length; i++) {
            // Execute the call
            success = execute(tos[i], values[i], datas[i], gasleft());

            // If the call was unsuccessful, break the loop
            if (!success) {
                break;
            }
        }
    }
}

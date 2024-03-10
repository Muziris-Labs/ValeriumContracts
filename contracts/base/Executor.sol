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
    function batchExecute(address[] memory tos, uint256[] memory values, bytes[] memory datas) internal returns (bool allSuccess){
        // Ensure that the lengths of the 'tos', 'values', and 'datas' arrays are all the same
        require(tos.length == values.length && tos.length == datas.length, "Array lengths must match");

        // Iterate over the 'tos' array
        for (uint i = 0; i < tos.length; i++) {
            // Start of assembly block
            assembly {
                // Load the 'to' address for the current iteration
                let to := mload(add(tos, mul(add(i, 1), 0x20)))
                // Load the 'value' amount for the current iteration
                let value := mload(add(values, mul(add(i, 1), 0x20)))
                // Calculate the start of the 'data' for the current iteration
                let data := add(datas, mul(add(i, 1), 0x20))
                // Load the length of the 'data' for the current iteration
                let dataLength := mload(add(datas, mul(i, 0x20)))

                // Execute the call and store the success status
                let result := call(gas(), to, value, data, dataLength, 0, 0)

                // If the call was not successful, revert the transaction
                switch iszero(result)
                case 1 {
                    allSuccess := 0
                    revert(0, 0)
                }
             }
        }
    }
}

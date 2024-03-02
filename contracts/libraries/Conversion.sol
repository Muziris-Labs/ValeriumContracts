// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

/**
 * @title Conversion - A contract that can convert between different types
 * @notice This contract is a library that provides functions to convert between different types
 * @author Anoy Roy Chowdhury - <anoyroyc3545@gmail.com>
 */

library Conversion {
    /**
     * @notice Converts a bytes32 value to a left padded bytes32 value
     * @dev This function is used to convert a bytes32 value to a padded bytes32 value
     * @param value The bytes32 value to be converted
     * @return paddedValue The padded bytes32 value
     */
    function convertToPaddedByte32(bytes32 value) internal pure returns (bytes32) {
        bytes32 paddedValue;
        paddedValue = bytes32(uint256(value) >> (31 * 8));
        return paddedValue;
    } 

    /**
     * @notice Converts a bytes32 message and a bytes32 hash to an array of padded bytes32 values
     * @dev This function is used to convert a bytes32 message and a bytes32 hash to an array of padded bytes32 values
     * @param _message The bytes32 message to be converted
     * @param _hash The bytes32 hash to be converted
     * @return byte32Inputs The array of padded bytes32 values
     */
    function convertToInputs(bytes32 _message, bytes32 _hash) internal pure returns (bytes32 [] memory){
        bytes32[] memory byte32Inputs = new bytes32[](64);
        // Convert the message to padded bytes32 values
        for (uint256 i = 0; i < 32; i++) {
            byte32Inputs[i] = convertToPaddedByte32(_message[i]);
        }
        // Apprend the hash to the array of padded bytes32 values
        for (uint256 i = 0; i < 32; i++) {
            byte32Inputs[i + 32] = convertToPaddedByte32(_hash[i]);
        }
        return byte32Inputs;
    }

    /**
     * @notice Converts a uint256 value to a string
     * @dev This function is used to convert a uint256 value to a string
     * @param v The uint256 value to be converted
     * @return string The string value
     */
    function uintToString(uint256 v) internal pure returns (string memory) {
        // If the input is zero, return "0"
        if (v == 0) {
            return "0";
        }
        // Maximum length for the bytes array
        uint256 maxlength = 100;
        // Create a new bytes array to hold the reversed string
        bytes memory reversed = new bytes(maxlength);
        // Initialize a counter to keep track of the length of the string
        uint256 i = 0;
        // While the input number is not zero
        while (v != 0) {
            // Calculate the remainder of the input number divided by 10
            uint256 remainder = v % 10;
            // Divide the input number by 10
            v = v / 10;
            // Convert the remainder to its ASCII character equivalent and add it to the reversed string
            reversed[i++] = bytes1(uint8(48 + remainder));
        }
        // Create a new bytes array to hold the final string
        bytes memory s = new bytes(i);
        // Reverse the reversed string to get the final string
        for (uint256 j = 0; j < i; j++) {
            s[j] = reversed[i - 1 - j];
        }
        // Convert the bytes array to a string and return it
        return string(s);
    }

    /**
     * @notice Converts a string message to a bytes32 hash
     * @dev The function is used to hash a message with Ethereum's standard prefix
     * @param message The string message to be converted
     * @return bytes32 The bytes32 hash
     */
    function hashMessage(string memory message) internal pure returns (bytes32) {
        // Define Ethereum's standard prefix for signed messages
        string memory messagePrefix = "\x19Ethereum Signed Message:\n";
        // Convert the length of the message to a string
        string memory lengthString = uintToString(bytes(message).length);
        // Concatenate the prefix, length string, and actual message into a single string
        string memory concatenatedMessage = string(abi.encodePacked(messagePrefix, lengthString, message));
        // Hash the concatenated message using keccak256 and return the result
        return keccak256(bytes(concatenatedMessage));
    }
}
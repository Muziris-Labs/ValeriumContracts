// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;
import "./Verifier.sol";
import "../libraries/Conversion.sol";

/**
 * @title Proof Manager - Converts nonces and given hash to public inputs and verifies the proof
 * @notice This contract is a base contract for converting nonces and given hash to public inputs and verifying the proof
 * @author Anoy Roy Chowdhury - <anoyroyc3545@gmail.com>
 */

abstract contract ProofManager is Verifier{
    /**
     * @notice Verifies the proof and returns the result of verification.
     * @param _proof The proof inputs
     * @param _nonce The nonce
     * @param _hash The hash
     * @param _verifier The address of the verifier contract
     */
    function verify(
        bytes calldata _proof,
        uint256 _nonce,
        bytes32 _hash,
        address _verifier
    ) internal view returns (bool) {
        bytes32[] memory publicInputs;

        // Use scope here to limit variable lifetime and prevent `stack too deep` errors
        {
            bytes32 message = Conversion.hashMessage(Conversion.uintToString(_nonce));
            publicInputs = Conversion.convertToInputs(message, _hash);
        }
        return verifyProof(_proof, publicInputs, _verifier);
    }

    /**
     * @notice Verifies the proof and returns the result of verification. This overload is used for verifying the proof with EIP-1271 signature.
     * @param _proof The proof inputs
     * @param _message The Message
     * @param _hash The hash
     * @param _verifier The address of the verifier contract
     */
    function verify(
        bytes calldata _proof,
        bytes32 _message,
        bytes32 _hash,
        address _verifier
    ) internal view returns (bool) {
        bytes32[] memory publicInputs = Conversion.convertToInputs(_message, _hash);
        return verifyProof(_proof, publicInputs, _verifier);
    }
}
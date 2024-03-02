// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

/**
 * @title Verifier - A contract that acts as a base contract for verifying Noir based ZK proofs 
 * @notice This contract is a base contract for verifying ZK proofs. The Verfier Contracts should be deployed independently and should be passed
 *         as a parameter to the "verifyProof" function of this contract. 
 * @author Anoy Roy Chowdhury - <anoyroyc3545@gmail.com>
 */


interface UltraVerifierInterface {
    /**
     * @notice Verifies the proof and returns the result of verification.
     * @param _proof The proof inputs
     * @param _publicInputs The public inputs
     */
    function verify(bytes calldata _proof, bytes32[] calldata _publicInputs) external view returns (bool);
}

abstract contract Verifier {
    /**
     * @notice Verifies the proof and returns the result of verification.
     * @param _proof The proof inputs
     * @param _publicInputs The public inputs
     * @param _verifier The address of the verifier contract
     */
    function verifyProof(
        bytes calldata _proof,
        bytes32[] memory _publicInputs,
        address _verifier
    ) internal view returns (bool) {
        return UltraVerifierInterface(_verifier).verify(_proof, _publicInputs);
    }
}




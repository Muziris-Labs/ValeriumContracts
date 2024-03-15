// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

/**
 * @title ProofHandler - A generic base contract that allows callers to add and check proofs.
 * @notice Proofs are added to a linked list and checked for duplicates. Only to be used for verifying server proofs.
 * @author Anoy Roy Chowdhury - <anoyroyc3545@gmail.com>
 */

abstract contract ProofHandler{
    bytes32 internal constant SENTINEL_PROOF = bytes32(uint256(1));

    mapping(bytes32 => bytes32) internal proofs;

    /**
     * @notice Initializes the linked list with the sentinel value.
     */
    constructor() {
        proofs[SENTINEL_PROOF] = SENTINEL_PROOF;
    }

    /**
     * @notice Adds a proof to the linked list.
     * @param proof The proof to be added.
     */
    function addProof(bytes calldata proof) internal {
        bytes32 proofHash = keccak256(proof);

        // Check if proof already exists
        require(proofs[proofHash] == bytes32(uint256(0)), "Proof already exists");

        // Invalid proof, chances of hash collision are negligible
        require(proofHash != SENTINEL_PROOF, "Invalid proof");

        proofs[proofHash] = proofs[SENTINEL_PROOF];
        proofs[SENTINEL_PROOF] = proofHash;
    }

    /**
     * Checks if the proof is a duplicate.
     * @param proof The proof to be checked.
     */
    function isProofDuplicate(bytes calldata proof) internal view returns (bool) {
        return SENTINEL_PROOF != keccak256(proof) && proofs[keccak256(proof)] != bytes32(uint256(0));
    }
}
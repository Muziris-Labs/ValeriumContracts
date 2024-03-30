// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

import "./ProofHandler.sol";
import "../base/Verifier.sol";

/**
 * @title Server Manager - This contract is used to verify if the server is calling the designated function.
 * @notice Proofs are added to a linked list and checked for duplicates. Only to be used for verifying server proofs.
 * @dev This contract is a base contract for adding,checking & verifying server proofs.
 * @notice Not used for initial implementation.
 * @author Anoy Roy Chowdhury - <anoyroyc3545@gmail.com>
*/

abstract contract ServerManager is ProofHandler, Verifier {
    /**
     * @notice Verifies the proof and returns the result of verification.
     * @param _proof The proof inputs
     * @param _serverHash The server hash
     * @param _verifier The address of the verifier contract
     */
    function verify(
        bytes calldata _proof,
        bytes32 _serverHash,
        address _verifier,
        uint256 _amount,
        address _token
    ) internal returns (bool) {
        bytes32[] memory publicInputs;
        
        require(isProofDuplicate(_proof) == false, "Proof already exists");

        // Add the proof to prevent reuse
        addProof(_proof);

        // Use scope here to limit variable lifetime and prevent `stack too deep` errors
        {
            publicInputs = new bytes32[](4);
            publicInputs[0] = _serverHash;
            publicInputs[1] = bytes32(getChainId());
            publicInputs[2] = bytes32(_amount);
            publicInputs[3] = bytes32(uint256(uint160(_token)) << 96);
        }
       
        return verifyProof(_proof, publicInputs, _verifier);
    }

     /**
     * @notice Returns the ID of the chain the contract is currently deployed on.
     * @return The ID of the current chain as a uint256.
     */
    function getChainId() public view returns (uint256) {
        uint256 id;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            id := chainid()
        }
        return id;
    }
}
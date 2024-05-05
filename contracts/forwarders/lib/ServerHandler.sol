// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

import "../../cross-chain/ProofHandler.sol";
import "../../base/Verifier.sol";


/**
 * @title ServerHandler - A contract that handles the server verification process.
 * @notice This contract is used to verify the server proof and return the result of verification.
 * @author Anoy Roy Chowdhury - <anoyroyc3545@gmail.com>
 */

abstract contract ServerHandler is ProofHandler, Verifier {

    // The address of the genesis address.
    address private GenesisAddress;

    // The address of the server verifier contract.
    address internal ServerVerifier;

    // The hash of the server.
    bytes32 internal serverHash;

    /**
     * @notice Initializes the genesis address.
     */
    constructor() {
        GenesisAddress = msg.sender;
    }

    /**
     * @dev Checks if the caller is the genesis address.
     */
    modifier onlyGenesis() {
        require(msg.sender == GenesisAddress, "Only genesis can call this function");
        _;
        
    }

    /**
     * @notice Transfers the genesis address to a new address.
     * @param _newGenesis The address of the new genesis
     */
    function transferGenesis(address _newGenesis) external onlyGenesis {
        GenesisAddress = _newGenesis;
    }

    /**
     * @notice Sets the server verifier and server hash.
     * @param _serverVerifier The address of the server verifier contract
     * @param _serverHash The hash of the server
     */
    function setupServer(address _serverVerifier, bytes32 _serverHash) onlyGenesis external {
        ServerVerifier = _serverVerifier;
        serverHash = _serverHash;
    }

    /**
     * @notice Verifies the proof and returns the result of verification.
     * @param _proof The proof inputs
     * @param _serverHash The server hash
     * @param _verifier The address of the verifier contract
     * @param _domain The domain
     * @param _addr The address
     */
    function verify(
        bytes calldata _proof,
        bytes32 _serverHash,
        address _verifier,
        bytes4 _domain,
        address _addr
    ) internal returns (bool) {
        bytes32[] memory publicInputs;
        
        require(isProofDuplicate(_proof) == false, "Proof already exists");

        // Add the proof to prevent reuse
        addProof(_proof);

        // Use scope here to limit variable lifetime and prevent `stack too deep` errors
        {
            publicInputs = new bytes32[](4);
            publicInputs[0] = _serverHash;
            publicInputs[1] = bytes32(uint256(uint32(_domain)));
            publicInputs[2] = bytes32(getChainId());
            publicInputs[3] = bytes32(uint256(uint160(_addr)));
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
// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

import "./ServerManager.sol";
import "./TeamManager.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

/**
 * @title Valerium Vault - This contract is used to manage the vault for the Valerium protocol.
 * @notice This contract is used to manage the vault for the Valerium protocol.
 * @dev This contract is a base contract for managing the vault for the Valerium protocol.
 * @author Anoy Roy Chowdhury - <anoyroyc3545@gmail.com>
 */

contract ValeriumVault is ServerManager, TeamManager {

    event DepositReceived(address indexed token, address indexed sender, uint256 amount);
    event GenesisWithdrawal(address indexed token, uint256 amount);
    event MemberWithdrawal(address indexed token, address indexed member, uint256 amount);

    // The address of the account that initially created the vault contract.
    address private GenesisAddress;
    
    // The address of the server verifier contract.
    address public ServerVerifier;

    // The hash of the server.
    bytes32 private serverHash;

    /**
     * @notice Initializes the contract with the server verifier and the server hash.
     * @param _serverVerifier The address of the server verifier contract.
     * @param _serverHash The hash of the server.
     */
    constructor (address _serverVerifier, bytes32 _serverHash) {
        GenesisAddress = msg.sender;
        ServerVerifier = _serverVerifier;
        serverHash = _serverHash;
    }

    /**
     * @notice Deposits the token into the vault.
     * @param token The address of the token to be deposited.
     * @param _amount The amount to be deposited.
     */
    function deposit (address token, uint256 _amount) payable external {
        if (token == address(0)) {
            require(msg.value == _amount, "Invalid amount");
        } else {
            require(IERC20(token).transferFrom(msg.sender, address(this), _amount), "Transfer failed");
        }

        emit DepositReceived(token, msg.sender, _amount);
    }

    /**
     * @notice Withdraws the token from the vault to the genesis address.
     * @param token The address of the token to be withdrawn.
     * @param _amount The amount to be withdrawn.
     */
    function withdraw (address token, uint256 _amount) external {
        require(msg.sender == GenesisAddress, "Unauthorized access");
        if (token == address(0)) {
            payable(msg.sender).transfer(_amount);
        } else {
            require(IERC20(token).transfer(msg.sender, _amount), "Transfer failed");
        }
        emit GenesisWithdrawal(token, _amount);
    }

    /**
     * @notice Adds a team member to the vault.
     * @param member The address of the member to be added.
     */
    function addTeamMember(address member) external {
        require(msg.sender == GenesisAddress, "Unauthorized access");
        addMember(member);
    }

    /**
     * @notice Removes a team member from the vault.
     * @param prevMember The address of the previous member.
     * @param member The address of the member to be removed.
     */
    function removeTeamMember(address prevMember, address member) external {
        require(msg.sender == GenesisAddress, "Unauthorized access");
        removeMember(prevMember, member);
    }

    /**
     * @notice Withdraws the token from the vault to the member address.
     * @param proof The proof inputs
     * @param token The address of the token to be withdrawn.
     * @param _amount The amount to be withdrawn.
     */
    function memberWithdrawal (bytes calldata proof, address token, uint256 _amount) external {
        require(isMember(msg.sender), "Unauthorized access");
        require(verify(proof, serverHash, ServerVerifier, _amount, token), "Invalid proof");

        if (token == address(0)) {
            payable(msg.sender).transfer(_amount);
        } else {
            require(IERC20(token).transfer(msg.sender, _amount), "Transfer failed");
        }

        emit MemberWithdrawal(token, msg.sender, _amount);
    }
}
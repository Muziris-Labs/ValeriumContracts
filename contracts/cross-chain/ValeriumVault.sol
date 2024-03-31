// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

import "./TeamManager.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

/**
 * @title Valerium Vault - This contract is used to manage the vault for the Valerium protocol.
 * @notice This contract is used to manage the vault for the Valerium protocol.
 * @dev This contract is a base contract for managing the vault for the Valerium protocol.
 * @author Anoy Roy Chowdhury - <anoyroyc3545@gmail.com>
 */

contract ValeriumVault is TeamManager {

    event DepositReceived(address indexed token, address indexed sender, uint256 amount);
    event GenesisWithdrawal(address indexed token, uint256 amount);
    event MemberWithdrawal(address indexed token, address indexed member, uint256 amount);
    event WithdrawAllGenesis(address indexed token);

    // The address of the account that initially created the vault contract.
    address private GenesisAddress;

    // The maximum withdrawal amount allowed in the vault by members.
    uint256 private maxWithdrawAmount = 0;

    // The snapshot time of the wallet.
    uint256 public snapshotTime;

    /**
     * @notice Initializes the contract with the address of the genesis account and maxDeposit.
     */
    constructor (uint256 _maxWithdrawAmount) {
        GenesisAddress = msg.sender;
        maxWithdrawAmount = _maxWithdrawAmount;
        snapshotTime = block.timestamp;
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
     * @notice Withdraws all the tokens from the vault to the genesis address.
     * @param token The address of the token to be withdrawn.
     */
    function withdrawAll (address token) external {
        require(msg.sender == GenesisAddress, "Unauthorized access");
        if (token == address(0)) {
            payable(msg.sender).transfer(address(this).balance);
        } else {
            IERC20(token).transfer(msg.sender, IERC20(token).balanceOf(address(this)));
        }
        emit WithdrawAllGenesis(token);
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
     * @param token The address of the token to be withdrawn.
     * @param _amount The amount to be withdrawn.
     */
    function memberWithdrawal (address token, uint256 _amount) external {
        // Check if the sender is a member
        require(isMember(msg.sender), "Unauthorized access");

        // Check if the amount is less than the maximum withdrawal amount
        require(_amount <= maxWithdrawAmount, "Invalid amount");

        // Withdraw the amount
        if (token == address(0)){
            require(_amount <= address(this).balance, "Insufficient balance");
            payable(msg.sender).transfer(_amount);
        } else {
            IERC20(token).transfer(msg.sender, _amount); 
        }

        emit MemberWithdrawal(token, msg.sender, _amount);
    }

    /**
     * @notice Updates the snapshot time of the vault.
     */
    function updateSnapshotTime() external {
        require(msg.sender == GenesisAddress || isMember(msg.sender), "Unauthorized access");
        snapshotTime = block.timestamp;
    }

    /**
     * @notice Transfers the ownership of the vault to a new genesis address.
     * @param newGenesis The address of the new genesis address.
     */
    function transferGenesis(address newGenesis) external {
        require(msg.sender == GenesisAddress, "Unauthorized access");
        GenesisAddress = newGenesis;
    }

    /**
     * @notice Changes the maximum withdrawal amount allowed in the vault by members.
     * @param _maxWithdrawAmount The new maximum withdrawal amount.
     */
    function changeMaxWithdrawAmount(uint256 _maxWithdrawAmount) external {
        require(msg.sender == GenesisAddress, "Unauthorized access");
        maxWithdrawAmount = _maxWithdrawAmount;
    }
}
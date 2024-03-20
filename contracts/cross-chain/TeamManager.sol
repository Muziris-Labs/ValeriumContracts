// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

/**
 * @title Team Manager - A generic base contract that allows callers to add and remove members.
 * @notice Members are added to a linked list and checked for duplicates. Only to be used for managing team members.
 * @dev This contract is a base contract for adding and removing members from a linked list.
 * @author Anoy Roy Chowdhury
 */

abstract contract TeamManager {
    address internal constant SENTINEL_MEMBER = address(0x1);

    mapping(address => address) internal members;

    /**
     * @notice Initializes the linked list with the sentinel value.
     */
    constructor() {
        members[SENTINEL_MEMBER] = SENTINEL_MEMBER;
    }

    /**
     * @notice Adds a member to the linked list.
     * @param member The member to be added.
     */
    function addMember(address member) internal {
        // Check if member is valid
        require(member != address(0) || member != SENTINEL_MEMBER, "Invalid member");
        // Check if member already exists
        require(members[member] == address(0), "Member already exists");
        members[member] = members[SENTINEL_MEMBER];
        members[SENTINEL_MEMBER] = member;
    }

    /**
     * @notice Removes a member from the linked list.
     * @param prevMember Previous member
     * @param member Member to be removed
     */
    function removeMember(address prevMember ,address member) internal {
        // Check if member is valid
        require (member != address(0) || member != SENTINEL_MEMBER, "Invalid member");
        // Check if member exists
        require (members[prevMember] == member, "Invalid member");
        members[prevMember] = members[member];
        members[member] = address(0);
    }

    /**
     * @notice Checks if the member is a part of the linked list.
     * @param member The member to be checked.
     */
    function isMember(address member) public view returns (bool) {
        return SENTINEL_MEMBER != member && members[member] != address(0);
    }

    /**
     * @notice Returns the members of the linked list.
     * @param start The start of the linked list or the sentinal address.
     * @param pageSize The size of the page.
     */
    function getMembersPaginated(address start, uint256 pageSize) public view returns (address[] memory array, address next) {
        require(start == SENTINEL_MEMBER && isMember(start), "Invalid start");
        require (pageSize != 0, "Invalid page size");
        // Init array with max page size
        array = new address[](pageSize);

        // Populate return array
        uint256 moduleCount = 0;
        next = members[start];
        while (next != address(0) && next != SENTINEL_MEMBER && moduleCount < pageSize) {
            array[moduleCount] = next;
            next = members[next];
            moduleCount++;
        }

        /**
          Because of the argument validation, we can assume that the loop will always iterate over the valid module list values
          and the `next` variable will either be an enabled module or a sentinel address (signalling the end). 
          
          If we haven't reached the end inside the loop, we need to set the next pointer to the last element of the modules array
          because the `next` variable (which is a module by itself) acting as a pointer to the start of the next page is neither 
          included to the current page, nor will it be included in the next one if you pass it as a start.
        */
        if (next != SENTINEL_MEMBER) {
            next = array[moduleCount - 1];
        }
        // Set correct size of returned array
        assembly {
            mstore(array, moduleCount)
        }
    }
}
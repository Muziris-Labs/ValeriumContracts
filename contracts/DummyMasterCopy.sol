// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

import "./common/Singleton.sol";
import "./common/StorageAccessible.sol";

/**
 * @title DummyMasterCopy - Dummy master copy contract to test the proxy factory.
 * @author Anoy Roy Chowdhury - <anoyroyc3545@gmail.com>
 */
contract DummyMasterCopy is Singleton, StorageAccessible{
    string public name;

    constructor() {
        name = "DummyMasterCopy";
    }

    function initialize(string memory _name) public {
        name = _name;
    }
}
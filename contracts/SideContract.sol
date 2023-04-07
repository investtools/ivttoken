// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IGigaToken.sol";


contract SideContract is AccessControl {
    IGigaToken public GigaToken;

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender); 
    }

    function setAddressGigaToken(address _addressGigaToken) external onlyRole(DEFAULT_ADMIN_ROLE) {
        GigaToken = IGigaToken(_addressGigaToken);
    }

    function gigaTokenMint(address _to, uint256 _amount) external {
        GigaToken.mint(_to, _amount);
    }
}
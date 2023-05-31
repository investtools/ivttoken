// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract GigaToken is ERC20, ERC20Burnable, ERC20Snapshot, AccessControl, Pausable, ERC20Permit {
    bytes32 public constant SNAPSHOT_ROLE = keccak256("SNAPSHOT_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    address public ZERO_ADDRESS = address(0);
    address public owner;
    mapping (address => uint) public unlockedTokens;

    constructor() ERC20("GigaToken", "GIGA") ERC20Permit("GigaToken") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(SNAPSHOT_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        owner = msg.sender;
    }

    function increaseUnlockedTokens(address _recipient, uint _amount) public onlyRole(MINTER_ROLE) {
        return _increaseUnlockedTokens(_recipient, _amount);
    }

    function decreaseUnlockedTokens(address _recipient, uint _amount) public onlyRole(MINTER_ROLE) {
        return _decreaseUnlockedTokens(_recipient, _amount);
    }

    function _increaseUnlockedTokens(address _from, uint _amount) internal {
        require(_amount >= 0, "Amount must be greater than zero");
        require(_from != ZERO_ADDRESS, "From must be an valid address");
        unlockedTokens[_from] += _amount;
    }  

    function _decreaseUnlockedTokens(address _from, uint _amount) internal {
        require(_amount > 0, "Amount must be greater than zero");
        require(_amount <= unlockedTokens[_from], "Amount must be less or equal than unlocked tokens");
        require(_from != ZERO_ADDRESS, "From must be an valid address");
        unlockedTokens[_from] -= _amount;
    }

    function _beforeTokenTransfer(address _from, address _to, uint256 _amount) internal whenNotPaused override(ERC20, ERC20Snapshot) {
        if (_from != ZERO_ADDRESS && _to != ZERO_ADDRESS) {
            require(_doesAddressHasEnoughUnlockedTokensToTransfer(_from, _amount), "Not enough unlocked tokens");
            _decreaseUnlockedTokens(_from, _amount);
        }
        super._beforeTokenTransfer(_from, _to, _amount);
    } 

    function snapshot() public onlyRole(SNAPSHOT_ROLE) {
        _snapshot();
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function mint(address _to, uint256 _amount) public onlyRole(MINTER_ROLE) {
        _mint(_to, _amount);
    }

    function _doesAddressHasEnoughUnlockedTokensToTransfer(address _from, uint256 _amount) internal view returns (bool) {
        return _amount <= unlockedTokens[_from];
    }

    function getUnlockedTokens(address _from) public view returns (uint) {
        return unlockedTokens[_from];
    }

}
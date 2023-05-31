// SPDX-License-Identifier: AGPLv3
pragma solidity 0.8.19;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract MultiSig is EIP712, ReentrancyGuard {
    using ECDSA for bytes32;

    event NewSigner(address signer);
    event NewTheshold(uint threshold);
    event SignerRemoved(address signer);
    event Execution(address destination, bool success, bytes returndata);

    // Multisig transaction payload
    struct TxnRequest {
        address to;
        uint256 value;
        bytes data;
        bytes32 nonce;
    }

    // Variables
    address[] public signers;
    mapping (address => bool) public isSigner;
    mapping (bytes32 => bool) public executed;
    uint256 public threshold;

    constructor(address _secondSigner, address _thirdSigner) EIP712("MultiSig", "1.0.0") {
        require(_secondSigner != address(0), "Second signer address cannot be the zero address");
        require(_thirdSigner != address(0), "Third signer address cannot be the zero address");
        require(_secondSigner != _thirdSigner, "Second signer address cannot be the third signer address");
        require(_secondSigner != msg.sender, "Second signer address cannot be the sender address");
        require(_thirdSigner != msg.sender, "Third signer address cannot be the sender address");

        threshold = 2;

        signers.push(msg.sender);
        signers.push(_secondSigner);
        signers.push(_thirdSigner);

        isSigner[msg.sender] = true;
        isSigner[_secondSigner] = true;
        isSigner[_thirdSigner] = true;
    }

    receive() external payable {}

    // @dev - returns hash of data to be signed
    // @param params - struct containing transaction data
    // @return - packed hash that is to be signed
    function typedDataHash(TxnRequest memory params) public view returns (bytes32) {
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    keccak256("TxnRequest(address to,uint256 value,bytes data,bytes32 nonce)"),
                    params.to,
                    params.value,
                    keccak256(params.data),
                    params.nonce
                )
            )
        );
        return digest;
    }

    // @dev - util function to recover a signer given a signatures
    // @param _to - to address of the transaction
    // @param _value - transaction value
    // @param _data - transaction calldata
    // @param _nonce - transaction nonce
    function recoverSigner(address _to, uint256 _value, bytes memory _data, bytes memory userSignature, bytes32 _nonce) public view returns (address) {
        TxnRequest memory params = TxnRequest({
            to: _to,
            value: _value,
            data: _data,
            nonce: _nonce
        });
        bytes32 digest = typedDataHash(params);
        // console.logBytes32(digest);
        return ECDSA.recover(ECDSA.toEthSignedMessageHash(digest), userSignature);
    }

    // @dev - addAdditionalOwners adds additional owners to the multisig
    // @param _signer - address to be added to the signers list
    function addAdditionalOwners(address _signer) public onlySigner {
        require(_signer != address(0), "Signer address cannot be the zero address");
        require(!isSigner[_signer], "Address is already a signer.");

        signers.push(_signer);
        isSigner[_signer] = true;

        emit NewSigner(_signer);
    }

    // @dev - resign removes owner from the multisig
    function resign() public onlySigner {
        require(signers.length > 2, "Cannot remove last 2 signers.");
        
        uint index = 0;
        for (uint i = 0; i < signers.length; i++) {
            if (signers[i] == msg.sender) {
                index = i;
                break;
            }
        }

        for (uint i = index; i < signers.length - 1; i++) {
            signers[i] = signers[i+1];            
        }
        signers.pop(); // delete the last item

        isSigner[msg.sender] = false;

        emit SignerRemoved(msg.sender);
    }

    // @dev - Execute a multisig transaction given an array of signatures, and TxnRequest params
    // @param signatures - array of signatures from multisig holders
    // @param _to - address a transaction should be sent to
    // @param _value - transaction value
    // @param _data - data to be sent with the transaction (e.g: to call a contract function)
    // @param _nonce - transaction nonce
    function executeTransaction(bytes[] memory signatures, address _to, uint256 _value, bytes memory _data, bytes32 _nonce) public onlySigner nonReentrant returns (bytes memory) {
        // require minimum # of signatures (m-of-n)
        require(signatures.length >= threshold, "Invalid number of signatures");
        require(_to != address(0), "Cannot send to zero address.");

        // construct transaction
        TxnRequest memory txn = TxnRequest({
            to: _to,
            value: _value,
            data: _data,
            nonce: _nonce
        });

        // create typed hash
        bytes32 digest = typedDataHash(txn);

        // verify replay
        require(!executed[digest], "Transaction has already been executed.");

        // get the signer of the message
        verifySigners(signatures, digest);	

        // execute transaction
        (bool success, bytes memory returndata) = txn.to.call{value: txn.value}(_data);
        require(success, "Failed transaction");
        executed[digest] = true;

        emit Execution(txn.to, success, returndata);

        return returndata;
    }

    // @dev - change the threshold for the multisig
    // @param _threshold - new threshold
    function changeThreshold(uint _threshold) public onlySigner {
        require(_threshold <= signers.length, "Threshold cannot exceed number of signers.");
        require(_threshold >= 2, "Threshold cannot be < 2.");
        threshold = _threshold;

        emit NewTheshold(threshold);
    }

    function getOwnerCount() public view returns (uint256) {
        return signers.length;
    }

    function getSigners() public view returns (address[] memory) {
        return signers;
    }

    function verifySigners(bytes[] memory signatures, bytes32 digest) public view returns (bool) {
        for (uint i = 0; i < threshold; i ++) {            
            // recover signer address
            address signer = ECDSA.recover(ECDSA.toEthSignedMessageHash(digest), signatures[i]);
            // verify that signer is owner (any signer can execute the transaction given a set of off-chain signatures)
            require(isSigner[signer], "Invalid signer");
        }
        return true;
    }
   
    modifier onlySigner() {
        require(isSigner[msg.sender], "Unauthorized signer.");
        _;
    }
}
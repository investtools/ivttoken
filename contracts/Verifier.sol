// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";

contract Verifier is EIP712 {
    using ECDSA for bytes32;

    // Multisig transaction payload
    struct TxnRequest {
        bytes32 nonce;
    }

    // Variables

    constructor() EIP712("Verifier", "1.0.0") {
    }

    receive() external payable {}

    // @dev - returns hash of data to be signed
    // @param params - struct containing transaction data
    // @return - packed hash that is to be signed
    function typedDataHash(TxnRequest memory params) public view returns (bytes32) {
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    keccak256("TxnRequest(bytes32 nonce)"),
                    params.nonce
                )
            )
        );
        return digest;
    }

    // @dev - util function to recover a signer given a signatures
    // @param _nonce - transaction nonce
    function recoverSigner(bytes32 _nonce, bytes memory userSignature) external view returns (address) {
        TxnRequest memory params = TxnRequest({
            nonce: _nonce
        });
        bytes32 digest = typedDataHash(params);
        return ECDSA.recover(digest, userSignature);
    }

} 
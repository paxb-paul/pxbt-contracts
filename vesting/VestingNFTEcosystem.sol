// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../erc20/IERC20.sol";
import "./MultiSignCoinTx.sol";
import "./MultiSignReceiverChangeTx.sol";

/**
 * @dev NFT Ecosystem Coin Transfer Plan contract
 *
 * Register 5 signatories for transaction permissions.
 * Coin transfer can only be executed with approval from 3 or more people.
 * All 5 people must approve to change the receiver wallet address.
 * Transfer is possible after a minimum of 48 hours.
 */
contract VestingNFTEcosystem is MultiSignCoinTx, MultiSignReceiverChangeTx {
    IERC20 public token;
    address public owner;
    address public receiver = 0xc30dbb789722Acf82312bD2983b3Efec9B257644;
    address[] public signers = [
        0xd5e7F7f96109Ea5d86ea58f8cEE67505d414769b,
        0xFB643159fB9d6B4064D0EC3a5048503deC72cAf2,
        0xaFdA9e685A401E8B791ceD4F13a3aB4Ed0ff12e3,
        0x0377DA3EA8c9b56E4428727FeF417eFf12950e3f,
        0x1bE9e3393617B74E3A92487a86EE2d2D4De0BfaA
    ];

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    /**
     * @dev Register 5 signer of coin transfer transaction and set the minimum number of approvals for execution to 3 signer.
     * Register 5 signer of change the receiver wallet address transaction and set the minimum number of approvals for execution to 5 signer.
     */
    constructor()
        MultiSignCoinTx(signers, 3)
        MultiSignReceiverChangeTx(signers, signers.length)
    {
        owner = msg.sender;
    }

    function setTokenAddress(address _token) public onlyOwner {
        token = IERC20(_token);
    }

    function getBalance() public view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function getTimestamp() public view returns (uint256) {
        return block.timestamp;
    }

    /**
     * @dev Execute a coin transfer transaction.
     * At least three signatures are required.
     */
    function coinTxExecute(
        uint256 _txId
    )
        public
        override
        onlyCoinTxSigner
        coinTxExists(_txId)
        coinTxNotExecuted(_txId)
        coinTxUnlocked(_txId)
    {
        require(
            getCoinTxApprovalCount(_txId) >= coinTxRequired,
            "The required number of approvals is insufficient"
        );

        CoinTransaction storage coinTransaction = coinTransactions[_txId];
        require(
            getBalance() >= coinTransaction.value,
            "Not enough for the balance"
        );

        token.transfer(receiver, coinTransaction.value);
        coinTransaction.executed = true;
        emit CoinTxExecute(_txId);
    }

    /**
     * @dev Execute a change the receiver wallet address transaction.
     * All five signatures are required.
     */
    function rcTxExecute(
        uint256 _txId
    ) public override onlyRcTxSigner rcTxExists(_txId) rcTxNotExecuted(_txId) {
        require(
            getRcTxApprovalCount(_txId) >= rcTxRequired,
            "The required number of approvals is insufficient"
        );

        RcTransaction storage rcTransaction = rcTransactions[_txId];
        receiver = rcTransaction.receiver;
        rcTransaction.executed = true;
        emit RcTxExecute(_txId);
    }
}

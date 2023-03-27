// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @dev Multi-Signed Coin Transfer
 */
contract MultiSignCoinTx {
    /**
     * @dev Emitted when submit coin transfer transaction.
     */
    event CoinTxSubmit(uint256 indexed txId);

    /**
     * @dev Emitted when approve coin transfer transaction.
     */
    event CoinTxApprove(address indexed signer, uint256 indexed txId);

    /**
     * @dev Emitted when revoke approval for transfer transaction of coin.
     */
    event CoinTxRevoke(address indexed signer, uint256 indexed txId);

    /**
     * @dev Emitted when execute coin transfer transaction.
     */
    event CoinTxExecute(uint256 indexed txId);

    struct CoinTransaction {
        uint256 value;
        uint256 delayTime;
        bool executed;
    }

    CoinTransaction[] public coinTransactions;
    address[] public coinTxSigners;
    uint256 public coinTxRequired;
    mapping(address => bool) public isCoinTxSigner;
    mapping(uint256 => mapping(address => bool)) public coinTxApproved;

    /**
     * @dev Modifier to make a function callable only the owner of permission.
     */
    modifier onlyCoinTxSigner() {
        require(isCoinTxSigner[msg.sender], "MultiSignCoinTx: not tx signer");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when a transaction exists.
     */
    modifier coinTxExists(uint256 _txId) {
        require(
            _txId < coinTransactions.length,
            "MultiSignCoinTx: tx does not exist"
        );
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the transaction is not approved.
     */
    modifier coinTxNotApproved(uint256 _txId) {
        require(
            !coinTxApproved[_txId][msg.sender],
            "MultiSignCoinTx: tx already approved"
        );
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the transaction is not executed.
     */
    modifier coinTxNotExecuted(uint256 _txId) {
        require(
            !coinTransactions[_txId].executed,
            "MultiSignCoinTx: tx already executed"
        );
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the transaction is at a viable time.
     */
    modifier coinTxUnlocked(uint256 _txId) {
        require(
            block.timestamp >= coinTransactions[_txId].delayTime,
            "MultiSignCoinTx: tokens have not been unlocked"
        );
        _;
    }

    /**
     * @dev Registers the owner of transaction permission.
     * Registers the minimum number of approvals to execute the transaction.
     */
    constructor(address[] memory _signers, uint256 _required) {
        require(_signers.length > 0, "MultiSignCoinTx: tx signers required");
        require(
            _required > 0 && _required <= _signers.length,
            "MultiSignCoinTx: invalid required number of tx signers"
        );

        for (uint256 i; i < _signers.length; i++) {
            address signer = _signers[i];
            require(signer != address(0), "MultiSignCoinTx: invalid tx signer");
            require(
                !isCoinTxSigner[signer],
                "MultiSignCoinTx: tx signer is not unique"
            );

            isCoinTxSigner[signer] = true;
            coinTxSigners.push(signer);
        }

        coinTxRequired = _required;
    }

    /**
     * @dev View the entire transaction.
     */
    function getCoinTransactions()
        external
        view
        returns (CoinTransaction[] memory)
    {
        return coinTransactions;
    }

    /**
     * @dev Submit coin transfer transaction.
     * Coin transfer execution requires 48 hours + additional time.
     */
    function coinTxSubmit(
        uint256 _value,
        uint256 _delayTime
    ) external onlyCoinTxSigner {
        coinTransactions.push(
            CoinTransaction({
                value: _value,
                delayTime: block.timestamp + 172800 + _delayTime,
                executed: false
            })
        );
        emit CoinTxSubmit(coinTransactions.length - 1);
    }

    /**
     * @dev Approve a coin transfer transaction.
     */
    function coinTxApprove(
        uint256 _txId
    )
        external
        onlyCoinTxSigner
        coinTxExists(_txId)
        coinTxNotApproved(_txId)
        coinTxNotExecuted(_txId)
    {
        coinTxApproved[_txId][msg.sender] = true;
        emit CoinTxApprove(msg.sender, _txId);
    }

    /**
     * @dev Returns the number of approvals for the transaction.
     */
    function getCoinTxApprovalCount(
        uint256 _txId
    ) public view returns (uint256 count) {
        for (uint256 i; i < coinTxSigners.length; i++) {
            if (coinTxApproved[_txId][coinTxSigners[i]]) {
                count += 1;
            }
        }
    }

    /**
     * @dev Cancel the approval of the coin transfer transaction.
     */
    function coinTxRevoke(
        uint256 _txId
    ) external onlyCoinTxSigner coinTxExists(_txId) coinTxNotExecuted(_txId) {
        require(
            coinTxApproved[_txId][msg.sender],
            "MultiSignCoinTx: tx not approved"
        );

        coinTxApproved[_txId][msg.sender] = false;
        emit CoinTxRevoke(msg.sender, _txId);
    }

    /**
     * @dev Execute a coin transfer transaction.
     */
    function coinTxExecute(
        uint256 _txId
    )
        public
        virtual
        onlyCoinTxSigner
        coinTxExists(_txId)
        coinTxNotExecuted(_txId)
        coinTxUnlocked(_txId)
    {
        require(
            getCoinTxApprovalCount(_txId) >= coinTxRequired,
            "MultiSignCoinTx: the required number of approvals is insufficient"
        );

        CoinTransaction storage coinTransaction = coinTransactions[_txId];
        coinTransaction.executed = true;
        emit CoinTxExecute(_txId);
    }
}

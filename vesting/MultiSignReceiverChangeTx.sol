// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @dev Multi-Signed change receiver wallet address
 */
contract MultiSignReceiverChangeTx {
    /**
     * @dev Emitted when submit change receiver wallet address transaction.
     */
    event RcTxSubmit(uint256 indexed txId);

    /**
     * @dev Emitted when approve change receiver wallet address transaction.
     */
    event RcTxApprove(address indexed signer, uint256 indexed txId);

    /**
     * @dev Emitted when revoke approval for change receiver wallet address transaction.
     */
    event RcTxRevoke(address indexed signer, uint256 indexed txId);

    /**
     * @dev Emitted when execute change receiver wallet address transaction.
     */
    event RcTxExecute(uint256 indexed txId);

    struct RcTransaction {
        address receiver;
        bool executed;
    }

    RcTransaction[] public rcTransactions;
    address[] public rcTxSigners;
    uint256 public rcTxRequired;
    mapping(address => bool) public isRcTxSigner;
    mapping(uint256 => mapping(address => bool)) public rcTxApproved;

    /**
     * @dev Modifier to make a function callable only the owner of permission.
     */
    modifier onlyRcTxSigner() {
        require(
            isRcTxSigner[msg.sender],
            "MultiSignReceiverChangeTx: not tx signer"
        );
        _;
    }

    /**
     * @dev Modifier to make a function callable only when a transaction exists.
     */
    modifier rcTxExists(uint256 _txId) {
        require(
            _txId < rcTransactions.length,
            "MultiSignReceiverChangeTx: tx does not exist"
        );
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the transaction is not approved.
     */
    modifier rcTxNotApproved(uint256 _txId) {
        require(
            !rcTxApproved[_txId][msg.sender],
            "MultiSignReceiverChangeTx: tx already approved"
        );
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the transaction is not executed.
     */
    modifier rcTxNotExecuted(uint256 _txId) {
        require(
            !rcTransactions[_txId].executed,
            "MultiSignReceiverChangeTx: tx already executed"
        );
        _;
    }

    /**
     * @dev Registers the owner of transaction permission.
     * Registers the minimum number of approvals to execute the transaction.
     */
    constructor(address[] memory _signers, uint256 _required) {
        require(
            _signers.length > 0,
            "MultiSignReceiverChangeTx: tx signers required"
        );
        require(
            _required > 0 && _required <= _signers.length,
            "MultiSignReceiverChangeTx: invalid required number of tx signers"
        );

        for (uint256 i; i < _signers.length; i++) {
            address signer = _signers[i];
            require(
                signer != address(0),
                "MultiSignReceiverChangeTx: invalid tx signer"
            );
            require(
                !isRcTxSigner[signer],
                "MultiSignReceiverChangeTx: tx signer is not unique"
            );

            isRcTxSigner[signer] = true;
            rcTxSigners.push(signer);
        }

        rcTxRequired = _required;
    }

    /**
     * @dev View the entire transaction.
     */
    function getRcTransactions()
        external
        view
        returns (RcTransaction[] memory)
    {
        return rcTransactions;
    }

    /**
     * @dev Submit change receiver wallet address transaction.
     */
    function rcTxSubmit(address _receiver) external onlyRcTxSigner {
        rcTransactions.push(
            RcTransaction({receiver: _receiver, executed: false})
        );
        emit RcTxSubmit(rcTransactions.length - 1);
    }

    /**
     * @dev Approve a change receiver wallet address transaction.
     */
    function rcTxApprove(
        uint256 _txId
    )
        external
        onlyRcTxSigner
        rcTxExists(_txId)
        rcTxNotApproved(_txId)
        rcTxNotExecuted(_txId)
    {
        rcTxApproved[_txId][msg.sender] = true;
        emit RcTxApprove(msg.sender, _txId);
    }

    /**
     * @dev Returns the number of approvals for the transaction.
     */
    function getRcTxApprovalCount(
        uint256 _txId
    ) public view returns (uint256 count) {
        for (uint256 i; i < rcTxSigners.length; i++) {
            if (rcTxApproved[_txId][rcTxSigners[i]]) {
                count += 1;
            }
        }
    }

    /**
     * @dev Cancel the approval of the change receiver wallet address transaction.
     */
    function rcTxRevoke(
        uint256 _txId
    ) external onlyRcTxSigner rcTxExists(_txId) rcTxNotExecuted(_txId) {
        require(
            rcTxApproved[_txId][msg.sender],
            "MultiSignReceiverChangeTx: tx not approved"
        );

        rcTxApproved[_txId][msg.sender] = false;
        emit RcTxRevoke(msg.sender, _txId);
    }

    /**
     * @dev Execute a change receiver wallet address transaction.
     */
    function rcTxExecute(
        uint256 _txId
    ) public virtual onlyRcTxSigner rcTxExists(_txId) rcTxNotExecuted(_txId) {
        require(
            getRcTxApprovalCount(_txId) >= rcTxRequired,
            "MultiSignReceiverChangeTx: the required number of approvals is insufficient"
        );

        RcTransaction storage rcTransaction = rcTransactions[_txId];
        rcTransaction.executed = true;
        emit RcTxExecute(_txId);
    }
}

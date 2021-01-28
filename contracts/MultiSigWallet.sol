pragma solidity ^0.5.0;

contract MultiSigWallet {

    address[] private owners;
    mapping (address => bool) private isOwner;
    uint private numberOfConfirmationsRequired;

    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
        uint numberOfConfirmations;
    }

    mapping(uint => mapping(address => bool)) private isConfirmed;
    Transaction[] private transactions;

    modifier onlyOwner() {
        require(isOwner[msg.sender],"Not Owner");
        _;
    }

    modifier transactionExists(uint _transactionIndex) {
        require(_transactionIndex < transactions.length, "transaction doesnot exist");
        _;
    }

    modifier notExecuted(uint _transactionIndex) {
        require(!transactions[_transactionIndex].executed, "transaction already executed");
        _;
    }

    modifier notConfirmed(uint _transactionIndex) {
        require(!isConfirmed[_transactionIndex][msg.sender], "transaction already confirmed by user");
        _;
    }

    event SubmitTransaction(address indexed owner,address indexed to, uint value, uint indexed transactionIndex, bytes data);
    event ConfirmTransaction(address indexed owner, uint indexed transactionIndex);
    event ExecuteTransaction(address indexed owner, uint indexed transactionIndex);
    event RevokeConfirmation(address indexed owner, uint indexed transactionIndex);
    event Deposit(address indexed sender, uint amount, uint balance);

    constructor(address[] memory _owners, uint _numberOfConfirmationsRequired) public {
        require( _owners.length > 0, "At least one owner required");
        require( _numberOfConfirmationsRequired > 0 && _numberOfConfirmationsRequired <= _owners.length, "invalid number of required confirmations" );

        for(uint i = 0; i<_owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner],"owner cannot be added again");

            isOwner[owner] = true;
            owners.push(owner);
        }

        numberOfConfirmationsRequired = _numberOfConfirmationsRequired;
    }

    function() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    function submitTransaction(address _to, uint _value, bytes memory _data) public onlyOwner {
        uint transactionIndex = transactions.length;
        transactions.push(Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            numberOfConfirmations : 0
        }));
        emit SubmitTransaction(msg.sender, _to, _value, transactionIndex, _data);
    }

    function confirmTransaction(uint _transactionIndex) public
        onlyOwner
        transactionExists(_transactionIndex)
        notExecuted(_transactionIndex)
        notConfirmed(_transactionIndex) {
            Transaction storage transaction = transactions[_transactionIndex];
            isConfirmed[_transactionIndex][msg.sender] = true;
            transaction.numberOfConfirmations++;
            emit ConfirmTransaction(msg.sender, _transactionIndex);
    }

    function executeTransaction(uint _transactionIndex) public
        onlyOwner
        transactionExists(_transactionIndex)
        notExecuted(_transactionIndex)
        {
            Transaction memory transaction = transactions[_transactionIndex];
            require(transaction.numberOfConfirmations >= numberOfConfirmationsRequired);
            transaction.executed = true;
            (bool success, ) = transaction.to.call.value(transaction.value)(transaction.data);
            require(success,"transaction failed");
            emit ExecuteTransaction(msg.sender, _transactionIndex);
        }

    function revokeConfirmation(uint _transactionIndex) public
        onlyOwner
        transactionExists(_transactionIndex)
        notExecuted(_transactionIndex)
        {
            Transaction storage transaction = transactions[_transactionIndex];
            require(isConfirmed[_transactionIndex][msg.sender],"transaction not confirmed");
            transaction.numberOfConfirmations--;
            isConfirmed[_transactionIndex][msg.sender] = false;
            emit RevokeConfirmation(msg.sender, _transactionIndex);
        }


}

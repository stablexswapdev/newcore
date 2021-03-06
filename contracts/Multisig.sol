/**
 *Submitted for verification at BscScan.com on 2020-11-08
*/


pragma solidity 0.5.8;
pragma experimental ABIEncoderV2;

interface IStableXPair {
    function depositAll0() external;  
    function depositAll1() external;
    function depositSome0(uint) external;
    function depositSome1(uint) external;
    function setY0(address) external;
    function setY1(address) external;
    function setFee(uint16) external;    
    function token0() external view returns (address);
    function token1() external view returns (address);           
}

interface IStableXFactory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

contract MultiSigWalletWithTimelock {

    uint256 constant public MAX_OWNER_COUNT = 50;
    // TODO: Update this factory address
    address constant public stablexFactory = address(0x32CE36F6eA8d97f9fC19Aab83b9c6D2F52D74470);

    uint256 public lockSeconds = 60;

    event Confirmation(address indexed sender, uint256 indexed transactionId);
    event Revocation(address indexed sender, uint256 indexed transactionId);
    event Submission(uint256 indexed transactionId);
    event Execution(uint256 indexed transactionId);
    event ExecutionFailure(uint256 indexed transactionId);
    event Deposit(address indexed sender, uint256 value);
    event OwnerAddition(address indexed owner);
    event OwnerRemoval(address indexed owner);
    event RequirementChange(uint256 required);
    event UnlockTimeSet(uint256 indexed transactionId, uint256 confirmationTime);
    event LockSecondsChange(uint256 lockSeconds);

    mapping (uint256 => Transaction) public transactions;
    mapping (uint256 => mapping (address => bool)) public confirmations;
    mapping (address => bool) public isOwner;
    mapping (uint256 => uint256) public unlockTimes;
    
    address[] public owners;
    uint256 public required;
    uint256 public transactionCount;

    struct Transaction {
        address destination;
        uint256 value;
        bytes data;
        bool executed;
    }

    struct EmergencyCall {
        bytes32 selector;
        uint256 paramsBytesCount;
    }

    // Functions bypass the time lock process
    EmergencyCall[] public emergencyCalls;

    modifier onlyWallet() {
        if (msg.sender != address(this))
            revert("ONLY_WALLET_ERROR");
        _;
    }

    modifier ownerDoesNotExist(address owner) {
        if (isOwner[owner])
            revert("OWNER_DOES_NOT_EXIST_ERROR");
        _;
    }

    modifier ownerExists(address owner) {
        if (!isOwner[owner])
            revert("OWNER_EXISTS_ERROR");
        _;
    }

    modifier transactionExists(uint256 transactionId) {
        if (transactions[transactionId].destination == address(0))
            revert("TRANSACTION_EXISTS_ERROR");
        _;
    }

    modifier confirmed(uint256 transactionId, address owner) {
        if (!confirmations[transactionId][owner])
            revert("CONFIRMED_ERROR");
        _;
    }

    modifier notConfirmed(uint256 transactionId, address owner) {
        if (confirmations[transactionId][owner])
            revert("NOT_CONFIRMED_ERROR");
        _;
    }

    modifier notExecuted(uint256 transactionId) {
        if (transactions[transactionId].executed)
            revert("NOT_EXECUTED_ERROR");
        _;
    }

    modifier notNull(address _address) {
        if (_address == address(0))
            revert("NOT_NULL_ERROR");
        _;
    }

    modifier validRequirement(uint256 ownerCount, uint256 _required) {
        if (ownerCount > MAX_OWNER_COUNT || _required > ownerCount || _required == 0 || ownerCount == 0)
            revert("VALID_REQUIREMENT_ERROR");
        _;
    }

    /** @dev Fallback function allows to deposit ether. */
    function() external payable {
        if (msg.value > 0) {
            emit Deposit(msg.sender, msg.value);
        }
    }

    /** @dev Contract constructor sets initial owners and required number of confirmations.
      * @param _owners List of initial owners.
      * @param _required Number of required confirmations.
      */
    constructor(address[] memory _owners, uint256 _required)
        public
        validRequirement(_owners.length, _required)
    {

        // YFII https://github.com/yfii/yvault/blob/master/contracts/standard/v2/bscconfig.json
        whiteListVault[0x1F19D041FDCE1B70901008229d77A8B02E315618] = true; // iUSDT
        whiteListVault[0xeB3C085FBc1030bb127114CB1A3B9A02A24eF62d] = true; // iBUSD
        whiteListVault[0x72dd5Df626ebBc020fdF431502799413c56Ac12C] = true; // iBNB
        whiteListVault[0xb98f8339CD3CD50701aCdE307875B78c373e6515] = true; // iETH        

        // dForce
        whiteListVault[0x03eFf545083D98063EDB933BF03D69c5D22409C3] = true; // dDAI
        whiteListVault[0xb2Dd446176cd19a754A936cdc124CD85Fb6d668e] = true; // dUSDT
        whiteListVault[0x5C90308849e666274ae6B0C9759E278Aa0d1b4Fc] = true; // dUSDC
        whiteListVault[0x96328E0ca47175eBB45D94df6fEd2B0Cb19CB16B] = true; // dBUSD        

        for (uint256 i = 0; i < _owners.length; i++) {
            if (isOwner[_owners[i]] || _owners[i] == address(0)) {
                revert("OWNER_ERROR");
            }

            isOwner[_owners[i]] = true;
        }

        owners = _owners;
        required = _required;

        // initialzie Emergency calls
        emergencyCalls.push(
            EmergencyCall({
                selector: keccak256(abi.encodePacked("setMarketBorrowUsability(uint16,bool)")),
                paramsBytesCount: 64
            })
        );
    }

    function getEmergencyCallsCount()
        external
        view
        returns (uint256 count)
    {
        return emergencyCalls.length;
    }

    /** @dev Allows to add a new owner. Transaction has to be sent by wallet.
      * @param owner Address of new owner.
      */
    function addOwner(address owner)
        external
        onlyWallet
        ownerDoesNotExist(owner)
        notNull(owner)
        validRequirement(owners.length + 1, required)
    {
        isOwner[owner] = true;
        owners.push(owner);
        emit OwnerAddition(owner);
    }

    /** @dev Allows to remove an owner. Transaction has to be sent by wallet.
      * @param owner Address of owner.
      */
    function removeOwner(address owner)
        external
        onlyWallet
        ownerExists(owner)
    {
        isOwner[owner] = false;
        for (uint256 i = 0; i < owners.length - 1; i++) {
            if (owners[i] == owner) {
                owners[i] = owners[owners.length - 1];
                break;
            }
        }

        owners.length -= 1;

        if (required > owners.length) {
            changeRequirement(owners.length);
        }

        emit OwnerRemoval(owner);
    }

    /** @dev Allows to replace an owner with a new owner. Transaction has to be sent by wallet.
      * @param owner Address of owner to be replaced.
      * @param owner Address of new owner.
      */
    function replaceOwner(address owner, address newOwner)
        external
        onlyWallet
        ownerExists(owner)
        ownerDoesNotExist(newOwner)
    {
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == owner) {
                owners[i] = newOwner;
                break;
            }
        }

        isOwner[owner] = false;
        isOwner[newOwner] = true;
        emit OwnerRemoval(owner);
        emit OwnerAddition(newOwner);
    }

    /** @dev Allows to change the number of required confirmations. Transaction has to be sent by wallet.
      * @param _required Number of required confirmations.
      */
    function changeRequirement(uint256 _required)
        public
        onlyWallet
        validRequirement(owners.length, _required)
    {
        required = _required;
        emit RequirementChange(_required);
    }

    /** @dev Changes the duration of the time lock for transactions.
      * @param _lockSeconds Duration needed after a transaction is confirmed and before it becomes executable, in seconds.
      */
    function changeLockSeconds(uint256 _lockSeconds)
        external
        onlyWallet
    {
        lockSeconds = _lockSeconds;
        emit LockSecondsChange(_lockSeconds);
    }

    /** @dev Allows an owner to submit and confirm a transaction.
      * @param destination Transaction target address.
      * @param value Transaction ether value.
      * @param data Transaction data payload.
      * @return Returns transaction ID.
      */
    function submitTransaction(address destination, uint256 value, bytes calldata data)
        external
        ownerExists(msg.sender)
        notNull(destination)
        returns (uint256 transactionId)
    {
        transactionId = transactionCount;
        transactions[transactionId] = Transaction({
            destination: destination,
            value: value,
            data: data,
            executed: false
        });
        transactionCount += 1;
        emit Submission(transactionId);
        confirmTransaction(transactionId);
    }

    /** @dev Allows an owner to confirm a transaction.
      * @param transactionId Transaction ID.
      */
    function confirmTransaction(uint256 transactionId)
        public
        ownerExists(msg.sender)
        transactionExists(transactionId)
        notConfirmed(transactionId, msg.sender)
    {
        confirmations[transactionId][msg.sender] = true;
        emit Confirmation(msg.sender, transactionId);

        if (isConfirmed(transactionId) && unlockTimes[transactionId] == 0 && !isEmergencyCall(transactionId)) {
            uint256 unlockTime = block.timestamp + lockSeconds;
            unlockTimes[transactionId] = unlockTime;
            emit UnlockTimeSet(transactionId, unlockTime);
        }
    }

    function isEmergencyCall(uint256 transactionId)
        internal
        view
        returns (bool)
    {
        bytes memory data = transactions[transactionId].data;

        for (uint256 i = 0; i < emergencyCalls.length; i++) {
            EmergencyCall memory emergencyCall = emergencyCalls[i];

            if (
                data.length == emergencyCall.paramsBytesCount + 4 &&
                data.length >= 4 &&
                emergencyCall.selector[0] == data[0] &&
                emergencyCall.selector[1] == data[1] &&
                emergencyCall.selector[2] == data[2] &&
                emergencyCall.selector[3] == data[3]
            ) {
                return true;
            }
        }

        return false;
    }

    /** @dev Allows an owner to revoke a confirmation for a transaction.
      * @param transactionId Transaction ID.
      */
    function revokeConfirmation(uint256 transactionId)
        external
        ownerExists(msg.sender)
        confirmed(transactionId, msg.sender)
        notExecuted(transactionId)
    {
        confirmations[transactionId][msg.sender] = false;
        emit Revocation(msg.sender, transactionId);
    }

    /** @dev Allows anyone to execute a confirmed transaction.
      * @param transactionId Transaction ID.
      */
    function executeTransaction(uint256 transactionId)
        external
        ownerExists(msg.sender)
        notExecuted(transactionId)
    {
        require(
            block.timestamp >= unlockTimes[transactionId],
            "TRANSACTION_NEED_TO_UNLOCK"
        );

        if (isConfirmed(transactionId)) {
            Transaction storage transaction = transactions[transactionId];
            transaction.executed = true;
            (bool success, ) = transaction.destination.call.value(transaction.value)(transaction.data);
            if (success)
                emit Execution(transactionId);
            else {
                emit ExecutionFailure(transactionId);
                transaction.executed = false;
            }
        }
    }

    /** @dev Returns the confirmation status of a transaction.
      * @param transactionId Transaction ID.
      * @return Confirmation status.
      */
    function isConfirmed(uint256 transactionId)
        public
        view
        returns (bool)
    {
        uint256 count = 0;

        for (uint256 i = 0; i < owners.length; i++) {
            if (confirmations[transactionId][owners[i]]) {
                count += 1;
            }

            if (count >= required) {
                return true;
            }
        }

        return false;
    }

    /* Web3 call functions */

    /** @dev Returns number of confirmations of a transaction.
      * @param transactionId Transaction ID.
      * @return Number of confirmations.
      */
    function getConfirmationCount(uint256 transactionId)
        external
        view
        returns (uint256 count)
    {
        for (uint256 i = 0; i < owners.length; i++) {
            if (confirmations[transactionId][owners[i]]) {
                count += 1;
            }
        }
    }

    /** @dev Returns total number of transactions after filers are applied.
      * @param pending Include pending transactions.
      * @param executed Include executed transactions.
      * @return Total number of transactions after filters are applied.
      */
    function getTransactionCount(bool pending, bool executed)
        external
        view
        returns (uint256 count)
    {
        for (uint256 i = 0; i < transactionCount; i++) {
            if (pending && !transactions[i].executed || executed && transactions[i].executed) {
                count += 1;
            }
        }
    }

    /** @dev Returns list of owners.
      * @return List of owner addresses.
      */
    function getOwners()
        external
        view
        returns (address[] memory)
    {
        return owners;
    }

    /** @dev Returns array with owner addresses, which confirmed transaction.
      * @param transactionId Transaction ID.
      * @return Returns array of owner addresses.
      */
    function getConfirmations(uint256 transactionId)
        external
        view
        returns (address[] memory _confirmations)
    {
        address[] memory confirmationsTemp = new address[](owners.length);
        uint256 count = 0;
        uint256 i;

        for (i = 0; i < owners.length; i++) {
            if (confirmations[transactionId][owners[i]]) {
                confirmationsTemp[count] = owners[i];
                count += 1;
            }
        }

        _confirmations = new address[](count);

        for (i = 0; i < count; i++) {
            _confirmations[i] = confirmationsTemp[i];
        }
    }
    
    /* StableX Routine Maintenance */
    
    mapping (address => bool) public whiteListVault;   
    
    modifier onlyWhiteListVault(address vault) {
        require(whiteListVault[vault], 'only whitelist vault');
        _;
    }
    
    modifier onlyStableXPair(address pair) {
        address token0 = IStableXPair(pair).token0();
        address token1 = IStableXPair(pair).token1();
        require(IStableXFactory(stablexFactory).getPair(token0, token1) == pair, "only StableX pair");
        _;
    }
    
    function depositAll0(address pair) external ownerExists(msg.sender) onlyStableXPair(pair) {
        IStableXPair(pair).depositAll0();
    }
    function depositAll1(address pair) external ownerExists(msg.sender) onlyStableXPair(pair) {
        IStableXPair(pair).depositAll1();        
    }
    function depositSome0(address pair, uint amount) external ownerExists(msg.sender) onlyStableXPair(pair) {
        IStableXPair(pair).depositSome0(amount);
    }
    function depositSome1(address pair, uint amount) external ownerExists(msg.sender) onlyStableXPair(pair) {
        IStableXPair(pair).depositSome1(amount);        
    }
    function setY0(address pair, address vault) external ownerExists(msg.sender) onlyWhiteListVault(vault) onlyStableXPair(pair) {
        IStableXPair(pair).setY0(vault);     
    }
    function setY1(address pair, address vault) external ownerExists(msg.sender) onlyWhiteListVault(vault) onlyStableXPair(pair) {
        IStableXPair(pair).setY1(vault);     
    }
    function setFee(address pair, uint16 _fee) external ownerExists(msg.sender) onlyStableXPair(pair) {
        IStableXPair(pair).setFee(_fee);     
    }    
    function addWhiteListVault(address vault) external onlyWallet {
        whiteListVault[vault] = true;
    }
    function removeWhiteListVault(address vault) external onlyWallet {
        whiteListVault[vault] = false;
    }
}
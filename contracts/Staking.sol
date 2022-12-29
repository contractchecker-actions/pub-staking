// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/Address.sol";

abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return payable(msg.sender);
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract Staking is Ownable {
    using Address for address;

    // Parameters
    uint128 public constant VALIDATOR_THRESHOLD = 1 ether;

    // Properties
    address[] public _validators;

    mapping(address => bool) public _addressToIsValidator;
    mapping(address => uint256) public _addressToStakedAmount;
    mapping(address => uint256) public _addressToValidatorIndex;
    uint256 public _stakedAmount;
    uint256 public _minimumNumValidators;
    uint256 public _maximumNumValidators;

    mapping(address => bytes) public _addressToBLSPublicKey;
    mapping(address => string) private _nodeID;

    // Events
    event Staked(address indexed account, uint256 amount);

    event Unstaked(address indexed account, uint256 amount);

    event BLSPublicKeyRegistered(address indexed accout, bytes key);

    event NodeIDRegistered(address indexed account, string nodeid);

    // Modifiers
    modifier onlyEOA() {
        require(!msg.sender.isContract(), "Only EOA can call function");
        _;
    }

    modifier onlyStaker() {
        require(
            _addressToStakedAmount[msg.sender] > 0,
            "Only staker can call function"
        );
        _;
    }

    modifier onlyValidator() {
        require(_isValidator(msg.sender), "Only validator can call function");
        _;
    }

    constructor(uint256 minNumValidators, uint256 maxNumValidators) {
        require(
            minNumValidators <= maxNumValidators,
            "Min validators num can not be greater than max num of validators"
        );
        _minimumNumValidators = minNumValidators;
        _maximumNumValidators = maxNumValidators;
    }

    // View functions
    function stakedAmount() public view returns (uint256) {
        return _stakedAmount;
    }

    function validators() public view returns (address[] memory) {
        return _validators;
    }

    function validatorBLSPublicKeys() public view returns (bytes[] memory) {
        bytes[] memory keys = new bytes[](_validators.length);

        for (uint256 i = 0; i < _validators.length; i++) {
            keys[i] = _addressToBLSPublicKey[_validators[i]];
        }

        return keys;
    }

    function isValidator(address addr) public view returns (bool) {
        return _addressToIsValidator[addr];
    }

    function accountStake(address addr) public view returns (uint256) {
        return _addressToStakedAmount[addr];
    }

    function minimumNumValidators() public view returns (uint256) {
        return _minimumNumValidators;
    }

    function maximumNumValidators() public view returns (uint256) {
        return _maximumNumValidators;
    }

    // Public functions
    receive() external payable onlyEOA {
        _stake();
    }

    function stake() public payable onlyEOA {
        _stake();
    }

    function unstake() public onlyEOA onlyStaker {
        _unstake();
    }

    function registerBLSPublicKey(string memory nodeid, bytes memory blsPubKey) public {
        _addressToBLSPublicKey[msg.sender] = blsPubKey;
        nodeID[msg.sender] = nodeid;
        emit BLSPublicKeyRegistered(msg.sender, blsPubKey);
    }

    function registerNodeID(string memory _node) public {
        _nodeID[msg.sender] = _node;

        emit NodeIDRegistered(msg.sender, _node);
    }

    // Private functions
    function _stake() private {
        _stakedAmount += msg.value;
        _addressToStakedAmount[msg.sender] += msg.value;

        if (_canBecomeValidator(msg.sender)) {
            _appendToValidatorSet(msg.sender);
        }

        emit Staked(msg.sender, msg.value);
    }

    function _unstake() private {
        uint256 amount = _addressToStakedAmount[msg.sender];

        _addressToStakedAmount[msg.sender] = 0;
        _stakedAmount -= amount;

        if (_isValidator(msg.sender)) {
            _deleteFromValidators(msg.sender);
        }

        payable(msg.sender).transfer(amount);
        emit Unstaked(msg.sender, amount);
    }

    function _deleteFromValidators(address staker) private {
        require(
            _validators.length > _minimumNumValidators,
            "Validators can't be less than the minimum required validator num"
        );

        require(
            _addressToValidatorIndex[staker] < _validators.length,
            "index out of range"
        );

        // index of removed address
        uint256 index = _addressToValidatorIndex[staker];
        uint256 lastIndex = _validators.length - 1;

        if (index != lastIndex) {
            // exchange between the element and last to pop for delete
            address lastAddr = _validators[lastIndex];
            _validators[index] = lastAddr;
            _addressToValidatorIndex[lastAddr] = index;
        }

        _addressToIsValidator[staker] = false;
        _addressToValidatorIndex[staker] = 0;
        _validators.pop();
    }

    function _appendToValidatorSet(address newValidator) private {
        require(
            _validators.length < _maximumNumValidators,
            "Validator set has reached full capacity"
        );

        _addressToIsValidator[newValidator] = true;
        _addressToValidatorIndex[newValidator] = _validators.length;
        _validators.push(newValidator);
    }

    function _isValidator(address account) private view returns (bool) {
        return _addressToIsValidator[account];
    }

    function _canBecomeValidator(address account) private view returns (bool) {
        return
            !_isValidator(account) &&
            _addressToStakedAmount[account] >= VALIDATOR_THRESHOLD;
    }

    function removeValidator(address _valAddress) external onlyOwner {
        _deleteFromValidators(_valAddress);
    }

    function removeBLSpubkey(address _addressOfBLSkey) external onlyOwner {
        delete _addressToBLSPublicKey[_addressOfBLSkey];
    }

    function addValidator(address _valAddress) external onlyOwner {
        _appendToValidatorSet(_valAddress);
    }

    function addBLSPublicKey(bytes memory blsPubKey, address _blsOwner) public onlyOwner {
        _addressToBLSPublicKey[_blsOwner] = blsPubKey;

        emit BLSPublicKeyRegistered(_blsOwner, blsPubKey);
    }

    function addNodeID(address _address, string memory _node) external onlyOwner {
        _nodeID[_address] = _node;

        emit NodeIDRegistered(msg.sender, _node);
    }

    function getNodeID(address _address) public view returns (string memory) {
        return _nodeID[_address];
    }
}

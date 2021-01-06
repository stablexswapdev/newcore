pragma solidity =0.6.12;

import './interfaces/IStableXv3Factory.sol';
import './StableXv3Pair.sol';

contract StableXv3Factory is IStableXv3Factory {
    address public override feeTo;
    address public override feeToSetter;

    mapping(address => mapping(address => address)) public override getPair;
    address[] public override allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    constructor() public {
        feeToSetter = msg.sender;
        feeTo = msg.sender;
    }

    function allPairsLength() external override view returns (uint) {
        return allPairs.length;
    }

    function pairCodeHash() external pure returns (bytes32) {
        return keccak256(type(StableXv3Pair).creationCode);
    }

    function createPair(address tokenA, address tokenB) external override returns (address pair) {
        require(tokenA != tokenB, 'StableXv3: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'StableXv3: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'StableXv3: PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(StableXv3Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        StableXv3Pair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external override {
        require(msg.sender == feeToSetter, 'StableXv3: FORBIDDEN');
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external override {
        require(msg.sender == feeToSetter, 'StableXv3: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }
}

pragma solidity =0.6.12;

import './interfaces/IStableXv3Externality.sol';
import './interfaces/IStableXv3Factory.sol';
import './interfaces/IStableXv3Pair.sol';

contract StableXv3Externality is IStableXv3Externality {

    address public pancake_factory;

    constructor() public {
    }

    function getReserves(address tokenA, address tokenB) external override view returns (uint r0, uint r1) {
        address pair = IStableXv3Factory(pancake_factory).getPair(tokenA, tokenB);
        if (pair != address(0)) {
            (r0, r1, ) = IStableXv3Pair(pair).getReserves();
        }
    }
}

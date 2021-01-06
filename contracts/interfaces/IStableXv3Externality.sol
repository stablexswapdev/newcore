pragma solidity =0.6.12;

interface IStableXv3Externality {
    function getReserves(address tokenA, address tokenB) external view returns (uint, uint);
}
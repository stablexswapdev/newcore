pragma solidity =0.6.12;

interface IStableXv3Callee {
    function StableXv3Call(address sender, uint amount0, uint amount1, bytes calldata data) external;
}

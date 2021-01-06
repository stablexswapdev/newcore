// Root file: contracts/interfaces/IWETH.sol

pragma solidity =0.6.12;
// This is to support interacting with weth like contracts (BNB on BSC)
interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}
// Root file: contracts/interfaces/IyToken.sol

pragma solidity =0.6.12;

//  This is a simple interface to deal with yfi style vaults 
interface IyToken {
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function deposit(uint) external;
    function withdraw(uint) external;    
    function balance() external view returns (uint);
}

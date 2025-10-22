// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title AutoTrader
/// @notice Simplified automated trader that can swap between two MinimalERC20 tokens using a basic constant product pool (x*y=k).
interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address who) external view returns (uint256);
}

contract AutoTrader {
    address public owner;
    IERC20 public tokenA;
    IERC20 public tokenB;
    uint256 public reserveA;
    uint256 public reserveB;
    uint256 public feeBps = 30; // 0.3%

    event SwapAForB(address indexed trader, uint256 amountA, uint256 amountBOut);
    event Provide(address indexed provider, uint256 amountA, uint256 amountB);

    constructor(address _a, address _b) {
        owner = msg.sender;
        tokenA = IERC20(_a);
        tokenB = IERC20(_b);
    }

    // provider must call approve for both tokens to this contract
    function provide(uint256 aAmount, uint256 bAmount) external {
        require(aAmount>0 && bAmount>0, "zero");
        require(tokenA.transferFrom(msg.sender, address(this), aAmount));
        require(tokenB.transferFrom(msg.sender, address(this), bAmount));
        reserveA += aAmount;
        reserveB += bAmount;
        emit Provide(msg.sender, aAmount, bAmount);
    }

    // simple constant product swap: trader sends A, receives B
    function swapAForB(uint256 amountAIn, uint256 minBOut) external {
        require(amountAIn > 0, "zero");
        require(tokenA.transferFrom(msg.sender, address(this), amountAIn));
        uint256 amountAInWithFee = amountAIn * (10000 - feeBps) / 10000;
        uint256 numerator = amountAInWithFee * reserveB;
        uint256 denominator = reserveA + amountAInWithFee;
        uint256 amountBOut = numerator / denominator;
        require(amountBOut >= minBOut, "slippage");
        reserveA += amountAIn;
        reserveB -= amountBOut;
        require(tokenB.transfer(msg.sender, amountBOut));
        emit SwapAForB(msg.sender, amountAIn, amountBOut);
    }

    // owner can withdraw fees or reserves
    function withdraw(address token, uint256 amount, address to) external {
        require(msg.sender == owner, "owner");
        if(token == address(tokenA)) {
            require(tokenA.transfer(to, amount));
            reserveA -= amount;
        } else if(token == address(tokenB)) {
            require(tokenB.transfer(to, amount));
            reserveB -= amount;
        } else revert("unknown");
    }
}

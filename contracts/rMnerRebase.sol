// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
import "./interface/ISwap.sol";
import "./utils/SafeERC20.sol";
import "./utils/Ownable.sol";
import "./interface/IR2MNER.sol";
import "./utils/SafeMath.sol";

contract rMnerRebase is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    ISwap private constant router =
        ISwap(0x4bD007912911f3Ee4b4555352b556B08601cE7Ce);

    address public immutable r2MNER;
    address public immutable exchangeAddress;

    constructor(address _r2MNER, address _exchangeAddress) Ownable(msg.sender) {

        require(_exchangeAddress != address(0), "Cannot be zero address");
        require(_r2MNER != address(0), "Cannot be zero address");
        
        r2MNER = _r2MNER;

        exchangeAddress = _exchangeAddress;
    }

    function buyrMner(uint128 amountIn, bytes memory path)
        public
        payable
        onlyOwner
    {
        ISwap.SwapAmountParams memory params = ISwap.SwapAmountParams({
            path: path,
            recipient: exchangeAddress,
            amount: amountIn,
            minAcquired: 0,
            deadline: block.timestamp
        });

        (, uint256 amountOut) = router.swapAmount{value: msg.value}(params);

        IR2MNER(r2MNER).rebase(int256(amountOut));
        emit SwapAndRebase(amountIn, amountOut);
    }

    event SwapAndRebase(uint128 amountIn, uint256 amountOut);

    function withdrawTokensSelf(address token, address to) external onlyOwner {
        require(to != address(0), "Address cannot be zero");
        if (token == address(0)) {
            (bool success, ) = payable(to).call{value: address(this).balance}(
                ""
            );
            if (!success) {
                revert();
            }
        } else {
            uint256 bal = IERC20(token).balanceOf(address(this));
            IERC20(token).safeTransfer(to, bal);
        }
        emit Withdraw(token, to);
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    event Received(address, uint256);

    event Withdraw(address token, address to);
}

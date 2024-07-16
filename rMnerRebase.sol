// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
import "https://github.com/izumiFinance/iZiSwap-periphery/blob/main/contracts/interfaces/ISwap.sol";
import "./utils/TransferHelper.sol";
import "./utils/Ownable.sol";
import "./interface/IR2MNER.sol";

contract rMnerRebase is Ownable {
    ISwap private constant router =
        ISwap(0x4bD007912911f3Ee4b4555352b556B08601cE7Ce);

    address r2MNER;
    address exchangeAddress;

    constructor(address _r2MNER, address _exchangeAddress) Ownable(msg.sender) {
        r2MNER = _r2MNER;
        exchangeAddress = _exchangeAddress;
    }

    function buyrMner(
        uint128 amountIn,
        bytes memory path
    ) public payable onlyOwner {
        ISwap.SwapAmountParams memory params = ISwap.SwapAmountParams({
            path: path,
            recipient: exchangeAddress,
            amount: amountIn,
            minAcquired: 0,
            deadline: block.timestamp
        });

        (, uint256 amountOut) = router.swapAmount{value: msg.value}(params);

        IR2MNER(r2MNER).rebase(amountOut);
        emit SwapAndRebase(amountIn, amountOut);
    }

    event SwapAndRebase(uint128 amountIn, uint256 amountOut);

    function withdrawTokensSelf(address token, address to) external onlyOwner {
        if (token == address(0)) {
            (bool success, ) = payable(to).call{value: address(this).balance}(
                ""
            );
            if (!success) {
                revert();
            }
        } else {
            uint256 bal = IERC20(token).balanceOf(address(this));
            IERC20(token).transfer(to, bal);
        }
        emit Withdraw(token, to);
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    event Received(address, uint256);

    event Withdraw(address token, address to);
}

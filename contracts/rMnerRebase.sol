// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
import "./interface/ISwap.sol";
import "./utils/SafeERC20.sol";
import "./utils/Ownable.sol";
import "./interface/IR2MNER.sol";
import "./utils/SafeMath.sol";
import "./utils/TransferHelper.sol";

contract rMnerRebase is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    ISwap private constant router =
        ISwap(0x1b81D678ffb9C0263b24A97847620C99d213eB14);

    address public immutable r2MNER;
    address public immutable BTC = 0xaEA9640259E91Cd5d4CAE0091c5590f7dAf29c85;
    address public immutable exchangeAddress;

    address public admin = 0x5467d7601ae4feF667A45fFAbcE57A346a0Ba116;

    bytes public path;

    uint256 public nextTime;

    uint256 public maxOutAmount = 500 * 1e18;

    error RMNERAmountInvalid();

    modifier onlyAdmin() {
        require(msg.sender == admin, "permissions error");
        _;
    }

    constructor(
        address _r2MNER,
        address _exchangeAddress,
        bytes memory path_
    ) Ownable(msg.sender) {
        require(_exchangeAddress != address(0), "Cannot be zero address");
        require(_r2MNER != address(0), "Cannot be zero address");

        r2MNER = _r2MNER;
        path = path_;
        exchangeAddress = _exchangeAddress;
    }

    function buyrMner(uint128 amountIn) public onlyAdmin {
        require(nextTime < block.timestamp, "Operating too quickly");

        IERC20(BTC).safeTransferFrom(msg.sender, address(this), amountIn);

        TransferHelper.safeApprove(BTC, address(router), amountIn);

        ISwap.ExactInputParams memory params = ISwap.ExactInputParams({
            path: path,
            recipient: exchangeAddress,
            amountIn: amountIn,
            amountOutMinimum: 0,
            deadline: block.timestamp
        });

        uint256 amountOut = router.exactInput(params);
        if (amountOut == 0 || amountOut > maxOutAmount) {
            revert RMNERAmountInvalid();
        }
        nextTime = block.timestamp + 300;
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

    function setAdmin(address admin_) external onlyOwner {
        require(admin_ != address(0), "Cannot be zero address");
        address prev = admin;
        admin = admin_;
        emit UpdateAdmin(prev, admin_);
    }

    function setMaxAmount(uint256 _max) external onlyOwner {
        uint256 prev = maxOutAmount;
        maxOutAmount = _max;
        emit UpdateMaxAmount(prev, _max);
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    event Received(address, uint256);
    event UpdateMaxAmount(uint256 pre, uint256 next);
    event Withdraw(address token, address to);
    event UpdateAdmin(address pre, address next);
}

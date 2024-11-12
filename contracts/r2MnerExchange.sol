// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;
import "./utils/SafeMath.sol";
import "./utils/SafeERC20.sol";
import "./utils/TransferHelper.sol";
import "./utils/Ownable.sol";
import "./utils/ReentrancyGuard.sol";
import "./interface/IERC20.sol";
import "./interface/ISwap.sol";

interface IRMNERPrice is IERC20 {
    function getPrice() external returns (uint256);
}

interface IRMnerExchange {
    function btcOutFee() external view returns (uint256);

    function btcInFee() external view returns (uint256);

    function swap(address tokenA, uint256 _amount) external payable;
}

contract r2MnerExchange is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    ISwap private constant router =
        ISwap(0x1b81D678ffb9C0263b24A97847620C99d213eB14);

    bytes public WETHPath;
    bytes public RMNERPath;
    address public immutable RMNER;
    address public immutable R2MNER;
    address public immutable rMnerExchange;
    address public immutable rMnerPrice;

    error AddressInvalid();

    event Withdraw(address token, uint256 amountIn, uint256 amountOut);
    event Deposit(address user, uint256 amountIn, uint256 amountOut);

    constructor(
        address _owner,
        address RMNER_,
        address R2MNER_,
        address rMnerExchange_,
        address rMnerPrice_,
        bytes memory WETHPath_,
        bytes memory RMNERPath_
    ) Ownable(_owner) {
        if (
            RMNER_ == address(0) ||
            R2MNER_ == address(0) ||
            rMnerExchange_ == address(0) ||
            rMnerPrice_ == address(0) ||
            _owner == address(0)
        ) {
            revert AddressInvalid();
        }
        RMNER = RMNER_;
        R2MNER = R2MNER_;
        rMnerExchange = rMnerExchange_;
        rMnerPrice = rMnerPrice_;

        RMNERPath = RMNERPath_;
        WETHPath = WETHPath_;
    }

    function deposit() public payable nonReentrant {
        ISwap.ExactInputParams memory params = ISwap.ExactInputParams({
            path: WETHPath,
            recipient: address(this),
            amountIn: msg.value,
            amountOutMinimum: 0,
            deadline: block.timestamp
        });
        uint256 amountOut = router.exactInput{value: msg.value}(params);

        TransferHelper.safeApprove(RMNER, rMnerExchange, amountOut);

        uint256 _feeRate = IRMnerExchange(rMnerExchange).btcInFee();

        uint256 _rMnerPrice = IRMNERPrice(rMnerPrice).getPrice();
        uint256 _btcFee = amountOut.mul(_feeRate).div(10000).mul(_rMnerPrice).div(10**18);

        IRMnerExchange(rMnerExchange).swap{value: _btcFee}(RMNER, amountOut);

        uint256 r2 = IERC20(R2MNER).balanceOf(address(this));

        IERC20(R2MNER).safeTransfer(msg.sender, r2);

        emit Deposit(msg.sender, msg.value, r2);
    }

    function withdraw(uint256 amount) public payable nonReentrant {
        IERC20(R2MNER).safeTransferFrom(msg.sender, address(this), amount);

        uint256 _feeRate = IRMnerExchange(rMnerExchange).btcOutFee();
        uint256 _rMnerPrice = IRMNERPrice(rMnerPrice).getPrice();

        uint256 _btcFee = amount.mul(_feeRate).div(10000).mul(_rMnerPrice).div(
            10**18
        );
        require(msg.value >= _btcFee, "Insufficient handling fee");

        uint256 amountIn = IERC20(R2MNER).balanceOf(address(this));

        TransferHelper.safeApprove(R2MNER, rMnerExchange, amountIn);

        IRMnerExchange(rMnerExchange).swap{value: _btcFee}(R2MNER, amountIn);

        uint256 amountOut = IERC20(RMNER).balanceOf(address(this));

        TransferHelper.safeApprove(RMNER, address(router), amountOut);

        ISwap.ExactInputParams memory params = ISwap.ExactInputParams({
            path: RMNERPath,
            recipient: msg.sender,
            amountIn: amountOut,
            amountOutMinimum: 0,
            deadline: block.timestamp
        });
        uint256 wethOut = router.exactInput(params);
        emit Withdraw(msg.sender, amount, wethOut);
    }

    function withdrawTokensSelf(address token, address to) external onlyOwner {
        require(to != address(0), "Cannot be zero address");
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
        emit WithdrawSelf(token, to);
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    event WithdrawSelf(address token, address to);
    event Received(address, uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./utils/SafeMath.sol";
import "./utils/SafeERC20.sol";
import "./utils/TransferHelper.sol";
import "./utils/Ownable.sol";
import "./utils/ReentrancyGuard.sol";

import "./interface/IR2MNER.sol";
import "./interface/IERC20.sol";

interface IRMNERPrice is IERC20 {
    function getPrice() external returns (uint256);
}

contract rMnerExchange is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public immutable rMNER;
    address public immutable r2MNER;

    address public rMnerPrice;

    address public feeReceive = 0x2cb60503C20027EE80502Dc291d09F36DfED026E;

    bool public stopSwap = false;

    uint256 public rate = 10000;

    uint256 public inFee = 0;
    uint256 public outFee = 0;

    uint256 public btcInFee = 0;
    uint256 public btcOutFee = 30;

    address assetManager;
    address admin;

    modifier onlyAssetManager() {
        require(msg.sender == assetManager, "permissions error");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "permissions error");
        _;
    }

    event Swap(
        address indexed user,
        address tokenA,
        address tokenB,
        uint256 inAmount,
        uint256 outAmount
    );

    constructor(
        address _rMNER,
        address _r2MNER,
        address _price,
        address _admin,
        address _assetManger
    ) Ownable(msg.sender) {
        require(_price != address(0), "Cannot be zero address");
        require(_assetManger != address(0), "Cannot be zero address");
        require(_admin != address(0), "Cannot be zero address");
        require(_rMNER != address(0), "Cannot be zero address");
        require(_r2MNER != address(0), "Cannot be zero address");
        rMNER = _rMNER;
        r2MNER = _r2MNER;
        rMnerPrice = _price;
        admin = _admin;
        assetManager = _assetManger;
    }

    function swap(address tokenA, uint256 _amount) public payable nonReentrant {
        require(stopSwap != true, "Exchange not opened");
        require(tokenA == rMNER || tokenA == r2MNER, "Unsupported tokens");

        if (tokenA == rMNER) {
            uint256 _rMnerFee = _amount.mul(inFee).div(10000);
            uint256 _amountInWithFee = _amount.sub(_rMnerFee);

            uint256 _outAmount = _amountInWithFee.mul(rate).div(10000);

            IERC20(tokenA).safeTransferFrom(msg.sender, address(this), _amount);
            if (_rMnerFee > 0) {
                IERC20(tokenA).safeTransfer(feeReceive, _rMnerFee);
            }
            _takeBtcFee(_amount, btcInFee);

            IR2MNER(r2MNER).mintTo(msg.sender, _outAmount);

            emit Swap(msg.sender, tokenA, r2MNER, _amount, _outAmount);
        } else {
            uint256 _outAmount = _amount.div(rate).mul(10000);

            uint256 _feeAmount = _getRMnerFee(_outAmount, outFee);
            _takeBtcFee(_outAmount, btcOutFee);

            TransferHelper.safeTransferFrom(
                r2MNER,
                msg.sender,
                address(this),
                _amount
            );
            uint256 r2MnerBalance = IR2MNER(r2MNER).balanceOf(address(this));
            IR2MNER(r2MNER).burn(r2MnerBalance);

            if (_feeAmount > 0) {
                IERC20(rMNER).safeTransfer(feeReceive, _feeAmount);
            }
            IERC20(rMNER).safeTransfer(msg.sender, _outAmount - _feeAmount);

            emit Swap(msg.sender, tokenA, rMNER, _amount, _outAmount);
        }
    }

    function _takeBtcFee(uint256 _amount, uint256 _feeRate)
        internal
        returns (uint256)
    {
        uint256 _feeAmount = _amount.mul(_feeRate).div(10000);
        uint256 _rMnerPrice = IRMNERPrice(rMnerPrice).getPrice();
        uint256 _btcFee = _feeAmount.mul(_rMnerPrice).div(10**18);

        if (_btcFee > 0) {
            require(msg.value >= _btcFee, "Insufficient handling fee");
            (bool rsuccess, ) = payable(feeReceive).call{value: _btcFee}("");
            if (!rsuccess) {
                revert();
            }
            uint256 _feeOver = msg.value - _btcFee;
            if (_feeOver > 0) {
                (bool success, ) = payable(msg.sender).call{value: _feeOver}(
                    ""
                );
                if (!success) {
                    revert();
                }
            }
        }
        return _btcFee;
    }

    function _getRMnerFee(uint256 _amount, uint256 _feeRate)
        internal
        pure
        returns (uint256)
    {
        uint256 _feeAmount = _amount.mul(_feeRate).div(10000);
        return _feeAmount;
    }

    function withdrawTokensSelf(address token, address to)
        external
        onlyAssetManager
    {
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
        emit Withdraw(token, to);
    }

    function setBtcFee(uint256 _in, uint256 _out) external onlyAdmin {
        btcInFee = _in;
        btcOutFee = _out;
        emit UpdateBtcFee(_in, _out);
    }

    function setFee(uint256 _in, uint256 _out) external onlyAdmin {
        inFee = _in;
        outFee = _out;
        emit UpdateFee(_in, _out);
    }

    function setSwapRate(uint256 _rate) external onlyAdmin {
        require(_rate > 0, "Ratio must be greater than 0");
        uint256 prev = rate;
        rate = _rate;
        emit UpdateRate(prev, _rate);
    }

    function setStopSwap(bool _stop) external onlyOwner {
        bool prev = stopSwap;
        stopSwap = _stop;
        emit UpdateSwapState(prev, _stop);
    }

    function setPriceAddress(address rMnerPrice_) external onlyOwner {
        require(rMnerPrice_ != address(0), "Cannot be zero address");
        address prev = rMnerPrice;
        rMnerPrice = rMnerPrice_;
        emit UpdateRMnerPrice(prev, rMnerPrice_);
    }

    function setFeeReceive(address feeReceive_) external onlyOwner {
        require(feeReceive_ != address(0), "Cannot be zero address");
        address prev = feeReceive;
        feeReceive = feeReceive_;
        emit UpdateFeeReceive(prev, feeReceive_);
    }

    function setAdmin(address admin_) external onlyOwner {
        require(admin_ != address(0), "Cannot be zero address");
        address prev = admin;
        admin = admin_;
        emit UpdateAdmin(prev, admin_);
    }

    function setAssetManager(address assetManager_) external onlyOwner {
        require(assetManager_ != address(0), "Cannot be zero address");
        address prev = assetManager;
        assetManager = assetManager_;
        emit UpdateAdmin(prev, assetManager_);
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    event Received(address, uint256);

    event Withdraw(address token, address to);
    event UpdateBtcFee(uint256 inFee, uint256 outFee);
    event UpdateFee(uint256 inFee, uint256 outFee);
    event UpdateSwapState(bool oldState, bool newState);
    event UpdateRate(uint256 oldRate, uint256 newRate);
    event UpdateRMnerPrice(address old, address newAddress);
    event UpdateFeeReceive(address old, address newAddress);

    event UpdateAdmin(address old, address newAddress);
    event UpdateAssetManager(address old, address newAddress);
}

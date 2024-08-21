// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "./utils/SafeMath.sol";
import "./utils/SafeMathInt.sol";
import "./utils/Ownable.sol";
import "./interface/IERC20.sol";
import "./interface/IRMNERBlack.sol";

contract r2MNER is IERC20, Ownable {
    using SafeMath for uint256;
    using SafeMathInt for int256;

    address internal constant INITIAL_TOKEN_HOLDER =
        0x000000000000000000000000000000000000dEaD;
    uint256 internal constant INFINITE_ALLOWANCE = ~uint256(0);

    string private _name;
    string private _symbol;

    uint256 _totalSupply;
    uint256 _totalShares;

    uint8 constant _decimals = 18;

    uint256 public lastEpoch = 0;

    mapping(address => uint256) private shares;

    mapping(address => mapping(address => uint256)) private allowances;

    address public monetaryPolicy;
    address public exchangePolicy;

    address immutable blackContract;

    // rebasing permissions
    modifier onlyMonetaryPolicy() {
        require(
            msg.sender == monetaryPolicy || msg.sender == owner(),
            "permissions error"
        );
        _;
    }

    modifier onlyExchangePolicy() {
        require(
            msg.sender == exchangePolicy || msg.sender == owner(),
            "permissions error"
        );
        _;
    }

    event TransferShares(
        address indexed from,
        address indexed to,
        uint256 sharesValue
    );

    event SharesBurnt(
        address indexed account,
        uint256 preRebaseTokenAmount,
        uint256 postRebaseTokenAmount,
        uint256 sharesAmount
    );
    event LogRebase(uint256 indexed epoch, uint256 totalSupply);

    event LogMonetaryPolicyUpdated(address monetaryPolicy);
    event LogExchangePolicyUpdated(address exchangePolicy);

    error BlackContractInvalid(address owner);

    constructor(
        string memory name_,
        string memory symbol_,
        address _blackContract
    ) Ownable(msg.sender) {
        _name = name_;
        _symbol = symbol_;

        if (_blackContract == address(0)) {
            revert BlackContractInvalid(address(0));
        }
        blackContract = _blackContract;
    }

    function mintTo(address to, uint256 _amount) public onlyExchangePolicy {
        _mint(to, _amount);
    }

    // update the rebaser
    function setMonetaryPolicy(address monetaryPolicy_) external onlyOwner {
        require(monetaryPolicy_ != address(0), "Cannot be zero address");
        monetaryPolicy = monetaryPolicy_;
        emit LogMonetaryPolicyUpdated(monetaryPolicy_);
    }

    // update the exchanger
    function setExchangePolicy(address exchangePolicy_) external onlyOwner {
        require(exchangePolicy_ != address(0), "Cannot be zero address");
        exchangePolicy = exchangePolicy_;
        emit LogExchangePolicyUpdated(exchangePolicy_);
    }

    function rebase(
        int256 _amount
    ) public onlyMonetaryPolicy returns (uint256) {
        if (_amount == 0) {
            lastEpoch += 1;
            emit LogRebase(lastEpoch, _totalSupply);
            return _totalSupply;
        }
        if (_amount < 0) {
            _totalSupply = _totalSupply.sub(uint256(_amount.abs()));
        } else {
            _totalSupply = _totalSupply.add(uint256(_amount));
        }
        lastEpoch += 1;
        emit LogRebase(lastEpoch, _totalSupply);
        return _totalSupply;
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(
        address _account
    ) public view override returns (uint256) {
        return getrMnerShares(_sharesOf(_account));
    }

    function transfer(
        address _recipient,
        uint256 _amount
    ) public virtual override returns (bool) {
        _transfer(msg.sender, _recipient, _amount);
        return true;
    }

    function burn(uint256 _amount) public virtual returns (bool) {
        _burn(msg.sender, _amount);
        return true;
    }

    function allowance(
        address _owner,
        address _spender
    ) public view override returns (uint256) {
        return allowances[_owner][_spender];
    }

    function approve(
        address _spender,
        uint256 _amount
    ) public override returns (bool) {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    function transferFrom(
        address _sender,
        address _recipient,
        uint256 _amount
    ) public override returns (bool) {
        _spendAllowance(_sender, msg.sender, _amount);
        _transfer(_sender, _recipient, _amount);
        return true;
    }

    function increaseAllowance(
        address _spender,
        uint256 _addedValue
    ) public virtual returns (bool) {
        _approve(
            msg.sender,
            _spender,
            allowances[msg.sender][_spender].add(_addedValue)
        );
        return true;
    }

    function decreaseAllowance(
        address _spender,
        uint256 _subtractedValue
    ) public virtual returns (bool) {
        uint256 currentAllowance = allowances[msg.sender][_spender];
        require(currentAllowance >= _subtractedValue, "ALLOWANCE_BELOW_ZERO");
        _approve(msg.sender, _spender, currentAllowance.sub(_subtractedValue));
        return true;
    }

    function getTotalShares() external view returns (uint256) {
        return _getTotalShares();
    }

    function sharesOf(address _account) external view returns (uint256) {
        return _sharesOf(_account);
    }

    function getSharesByR2Mner(
        uint256 _rMnerAmount
    ) public view returns (uint256) {
        return _rMnerAmount.mul(_getTotalShares()).div(_totalSupply);
    }

    function getrMnerShares(
        uint256 _sharesAmount
    ) public view returns (uint256) {
        return _sharesAmount.mul(_totalSupply).div(_getTotalShares());
    }

    function transferShares(
        address _recipient,
        uint256 _sharesAmount
    ) external returns (uint256) {
        _transferShares(msg.sender, _recipient, _sharesAmount);
        uint256 tokensAmount = getrMnerShares(_sharesAmount);
        _emitTransferEvents(
            msg.sender,
            _recipient,
            tokensAmount,
            _sharesAmount
        );
        return tokensAmount;
    }

    function transferSharesFrom(
        address _sender,
        address _recipient,
        uint256 _sharesAmount
    ) external returns (uint256) {
        uint256 tokensAmount = getrMnerShares(_sharesAmount);
        _spendAllowance(_sender, msg.sender, tokensAmount);
        _transferShares(_sender, _recipient, _sharesAmount);
        _emitTransferEvents(_sender, _recipient, tokensAmount, _sharesAmount);
        return tokensAmount;
    }

    function _transfer(
        address _sender,
        address _recipient,
        uint256 _amount
    ) internal virtual {
        uint256 _sharesToTransfer = getSharesByR2Mner(_amount);

        _transferShares(_sender, _recipient, _sharesToTransfer);
        _emitTransferEvents(_sender, _recipient, _amount, _sharesToTransfer);
    }

    function _approve(
        address _owner,
        address _spender,
        uint256 _amount
    ) internal virtual {
        require(_owner != address(0), "APPROVE_FROM_ZERO_ADDR");
        require(_spender != address(0), "APPROVE_TO_ZERO_ADDR");

        allowances[_owner][_spender] = _amount;
        emit Approval(_owner, _spender, _amount);
    }

    function _spendAllowance(
        address _owner,
        address _spender,
        uint256 _amount
    ) internal virtual {
        uint256 currentAllowance = allowances[_owner][_spender];
        if (currentAllowance != INFINITE_ALLOWANCE) {
            require(currentAllowance >= _amount, "ALLOWANCE_EXCEEDED");
            _approve(_owner, _spender, currentAllowance - _amount);
        }
    }

    function _getTotalShares() internal view returns (uint256) {
        return _totalShares;
    }

    function _sharesOf(address _account) internal view returns (uint256) {
        return shares[_account];
    }

    function _transferShares(
        address _sender,
        address _recipient,
        uint256 _sharesAmount
    ) internal {
        require(
            IRMNERBlack(blackContract).isR2MnerBlack(_sender) != true,
            "Abnormal account"
        );
        require(_sender != address(0), "TRANSFER_FROM_ZERO_ADDR");
        require(_recipient != address(0), "TRANSFER_TO_ZERO_ADDR");
        require(_recipient != address(this), "TRANSFER_TO_STETH_CONTRACT");

        uint256 currentSenderShares = _sharesOf(_sender);
        require(_sharesAmount <= currentSenderShares, "BALANCE_EXCEEDED");

        shares[_sender] = currentSenderShares.sub(_sharesAmount);
        shares[_recipient] = shares[_recipient].add(_sharesAmount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        uint256 _sharesAmount = _totalSupply == 0
            ? amount
            : getSharesByR2Mner(amount);

        shares[account] = shares[account].add(_sharesAmount);

        _totalShares = _getTotalShares().add(_sharesAmount);

        _totalSupply = _totalSupply.add(amount);

        emit Transfer(address(0), account, amount);
    }

    function _mintShares(
        address _recipient,
        uint256 _sharesAmount
    ) internal returns (uint256 newTotalShares) {
        require(_recipient != address(0), "MINT_TO_ZERO_ADDR");

        newTotalShares = _getTotalShares().add(_sharesAmount);
        _totalShares = newTotalShares;

        shares[_recipient] = shares[_recipient].add(_sharesAmount);

        return newTotalShares;
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");
        uint256 accountBalance = balanceOf(account);
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");

        uint256 _sharesAmount = getSharesByR2Mner(amount);

        shares[account] = shares[account].sub(_sharesAmount);

        _totalShares = _getTotalShares().sub(_sharesAmount);

        _totalSupply = _totalSupply.sub(amount);

        emit Transfer(account, address(0), amount);
    }

    function _burnShares(
        address _account,
        uint256 _sharesAmount
    ) internal returns (uint256 newTotalShares) {
        require(_account != address(0), "BURN_FROM_ZERO_ADDR");

        uint256 accountShares = shares[_account];
        require(_sharesAmount <= accountShares, "BALANCE_EXCEEDED");

        uint256 preRebaseTokenAmount = getrMnerShares(_sharesAmount);

        newTotalShares = _getTotalShares().sub(_sharesAmount);

        _totalShares = newTotalShares;
        shares[_account] = accountShares.sub(_sharesAmount);

        uint256 postRebaseTokenAmount = getrMnerShares(_sharesAmount);

        emit SharesBurnt(
            _account,
            preRebaseTokenAmount,
            postRebaseTokenAmount,
            _sharesAmount
        );
    }

    function _emitTransferEvents(
        address _from,
        address _to,
        uint256 _tokenAmount,
        uint256 _sharesAmount
    ) internal {
        emit Transfer(_from, _to, _tokenAmount);
        emit TransferShares(_from, _to, _sharesAmount);
    }

    function _emitTransferAfterMintingShares(
        address _to,
        uint256 _sharesAmount
    ) internal {
        _emitTransferEvents(
            address(0),
            _to,
            getrMnerShares(_sharesAmount),
            _sharesAmount
        );
    }

    function _mintInitialShares(uint256 _sharesAmount) internal {
        _mintShares(INITIAL_TOKEN_HOLDER, _sharesAmount);
        _emitTransferAfterMintingShares(INITIAL_TOKEN_HOLDER, _sharesAmount);
    }
}

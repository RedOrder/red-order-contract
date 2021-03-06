// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/GSN/Context.sol";
import "openzeppelin-contracts/math/SafeMath.sol";
import "openzeppelin-contracts/access/Ownable.sol";

contract TheRedORder is Context, Ownable, IERC20 {

    using SafeMath for uint256;

    // holds the balances of everyone who owes tokens of this contract
    mapping (address => uint256) private _balances;
    // holds the amount authorized by address
    mapping (address => mapping (address => uint256)) private _allowances;

    string  private _name               = "TheRedOrder";
    string  private _symbol             = "REDORDER";

    // 18 decimal contract
    uint8   private _decimals           = 18;
    // 1 trillion * decimal count
    uint256 private _totalSupply        = 1000000 * 10**6 * 10**18;

    // TODO: change this out with the final marketing wallet address
    address private _marketingWallet    = 0xdD870fA1b7C4700F2BD7f44238821C26f7392148;
    address private _liquidityWallet;

    // send total supply to the address that has created the contract
    constructor () {
        _balances[msg.sender] = _totalSupply;
        _liquidityWallet = msg.sender;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    // return name of the token
    function name() public view virtual returns (string memory) {
        return _name;
    }

    // return symbol of the token
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    // return decimals of token
    function decimals() public view virtual returns (uint8) {
        return _decimals;
    }

    // return amount in supply
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    // return the balance of tokens from the address passed in
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    // transfers amount from the person calling the function to 
    // the address called [@param 1] in the amount specified [@param 2]
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    // returns the amount authorized by one account [@param 1] to allow account 2 [@aram2] to spend 
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    // approves the person who calles this function to allow another address [@param1] to spend the 
    // amount specified [@param2]
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    // transferes from account 1 [@param1] to account 2 [@param 2] the designated amount [@param 3]
    // requires the person calling the function has at least the amount of the transfer authorized for them to send
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        _approve(sender, _msgSender(), currentAllowance - amount);

        return true;
    }

    // the person calling this function INCREASES the allowance of the address called [@param1] can spend
    // on their belave by the amount send [@param2]
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    // the person calling this function DECREASED the allowance of the address called [@param1] can spend
    // on their belave by the amount send [@param2]
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        _approve(_msgSender(), spender, currentAllowance - subtractedValue);

        return true;
    }

    // performs a transfer from address 1 [@param2] to address 2 [@param 2] in the amount
    // that is specified [@param 3]. Fees in the total amount of 14% are deducted. 2% goes
    // into a marketing walled, 2% is removed from total supply, 10% goes to liquidity pool
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender    != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        // amount to send to the marketing wallet (2%)
        uint256 marketingFee  = amount.div(100).mul(2);
        // amount to burn of the total supply (2%)
        uint256 burnFee       = amount.div(100).mul(2);
        // amount to send into pool (10%)
        uint256 liquidityFee  = amount.div(100).mul(8);

        // declare the amount the sender has in their account
        uint256 senderBalance = _balances[sender];

        // declare amount that actually gets transfered after burn, liquidity, and marketing fees
        uint256 totalTransfer = amount.sub(marketingFee).sub(burnFee).sub(liquidityFee);

        _beforeTokenTransfer(sender, recipient, amount);

        // require that the balaner of the person this transfer is coming from has the funds
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");

        // reduce the full amount from the sender's balance
        _balances[sender]             = _balances[sender].sub(amount);
        // add the after fees amount to the recipeint
        _balances[recipient]          = _balances[recipient].add(totalTransfer);
        // add the balance to the marketing wallet
        _balances[_marketingWallet]   = _balances[_marketingWallet].add(marketingFee);
          // send taxed amount to the contract
        _balances[_liquidityWallet]   = _balances[_liquidityWallet].add(liquidityFee);
        // add the burn balance to address 0
        _balances[address(0)]         = _balances[address(0)].add(burnFee);
      
        // subtract burn fee from total supply
        _totalSupply = _totalSupply.sub(burnFee);

        // transfer the after fee amount to the recipient
        emit Transfer(sender, recipient, totalTransfer);
        // transfer the marketing percent to the marketing wallet
        emit Transfer(sender, _marketingWallet, marketingFee);
        // send the tax amount to the liquidity wallet
        emit Transfer(sender, _liquidityWallet, liquidityFee);
        // transfer the burn fee to the 0 address
        emit Transfer(sender, address(0), burnFee);
    

    }

    // no need to check for balance here, _transfer function checks to see if the amount
    // being transfered is >= to the balance of the person sending the tokens
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }
}

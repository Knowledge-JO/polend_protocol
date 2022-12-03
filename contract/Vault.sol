// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./StableCoin.sol";


contract Vault is Ownable {
    
    AggregatorV3Interface public priceFeed;
    mapping(address => LoanDets) public loanDets;
    event Deposit(uint256 _collateral);
    event Borrowed(uint256 _amountBorrowed);
    event Repayed(uint256 _repayed);
    event Withdrawn(uint256 _withdrawAmount);
    enum State {NOT_SUPPLIED, SUPPLIED, BORROWED, REPAYED}
    
    constructor (address _priceFeed){
        priceFeed = AggregatorV3Interface(_priceFeed);
    }


    struct LoanDets {
        address user;
        uint256 collateralAmount;
        uint256 debt;
        StableCoin coin;
        State state;
    }


    function deposit(uint256 _depositAmountInWEI) public payable {
        require(msg.value == _depositAmountInWEI, "Not enough ether to deposit amount entered");
        uint256 collateral = getConversionRate(msg.value);
        loanDets[msg.sender].collateralAmount += collateral;
        loanDets[msg.sender].state = State.SUPPLIED;
        loanDets[msg.sender].user = msg.sender;
        emit Deposit(collateral);
    }


    function borrow(StableCoin _coin, uint256 amountToBorrow) public {
        //uint256 amountToBorrow = getConversionRate(_amountToBorrowInWEI);
        require(amountToBorrow < loanDets[msg.sender].collateralAmount, "");
        require(loanDets[msg.sender].state == State.SUPPLIED || loanDets[msg.sender].state == State.REPAYED);
        loanDets[msg.sender].coin = _coin;
        loanDets[msg.sender].debt += amountToBorrow;
        loanDets[msg.sender].coin.mint(msg.sender, amountToBorrow);
        loanDets[msg.sender].state = State.BORROWED;
        emit Borrowed(amountToBorrow);
    }


    function repay(uint256 repayAmount) public  {
        require(repayAmount == loanDets[msg.sender].debt);
        require(loanDets[msg.sender].coin.balanceOf(msg.sender) >= repayAmount);
        require(loanDets[msg.sender].state == State.BORROWED);
        loanDets[msg.sender].coin.burn(msg.sender, repayAmount);
        loanDets[msg.sender].debt -= repayAmount;
        loanDets[msg.sender].state = State.REPAYED;
        emit Repayed(repayAmount);
    }


    function withdraw(uint256 _withdrawAmount) public{
        require(loanDets[msg.sender].collateralAmount > 0);
        require(_withdrawAmount <= loanDets[msg.sender].collateralAmount);
        require(loanDets[msg.sender].state == State.REPAYED || loanDets[msg.sender].state == State.NOT_SUPPLIED);
        uint256 amountInMatic = _withdrawAmount * 10**18 / getPrice();
        payable(msg.sender).transfer(amountInMatic);
        loanDets[msg.sender].collateralAmount -= _withdrawAmount;
        if (loanDets[msg.sender].collateralAmount > 0) {
            loanDets[msg.sender].state = State.SUPPLIED;
        }else {
            loanDets[msg.sender].state = State.NOT_SUPPLIED;
        }
        emit Withdrawn(_withdrawAmount);
    }


    function getPrice() public view returns(uint256) {
        (,int256 answer,,,) = priceFeed.latestRoundData();
        return uint256(answer * 10**10);
    }

    
    function getConversionRate(uint256 maticAmount) public view returns(uint256) {
        uint256 maticPrice = getPrice();
        uint256 maticAmountInUSD = (maticPrice * maticAmount) / 10**18;    
        return maticAmountInUSD;
    }


    function updatePriceFeedAddress(address _priceFeed) public onlyOwner {
        priceFeed = AggregatorV3Interface(_priceFeed);
    }

}
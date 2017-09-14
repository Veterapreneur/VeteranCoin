pragma solidity ^0.4.11;


/**
 * Math operations with safety checks
 */
library SafeMath {
    function mul(uint a, uint b) internal returns (uint) {
        uint c = a * b;
        assert(a == 0 || c / a == b);
        return c;
    }

    function div(uint a, uint b) internal returns (uint) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        uint c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }

    function sub(uint a, uint b) internal returns (uint) {
        assert(b <= a);
        return a - b;
    }

    function add(uint a, uint b) internal returns (uint) {
        uint c = a + b;
        assert(c >= a);
        return c;
    }
}


contract owned {

    address public owner;

    function owned() {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address _newOwner) onlyOwner {
        owner = _newOwner;
    }
}

contract token {
    function balanceOf(address owner) constant returns (uint256 balance);
    function transfer(address _to, uint256 _value) returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value) returns (bool success);
    function burn(uint256 value) returns(bool success);
}

contract VeteranCoinSale is owned {

    using SafeMath for uint256;

    uint public tokenSold;
    uint public amountRaised;
    uint public startDate;
    uint public deadline;
    uint public weekTwo;
    uint public weekThree;
    uint public weekFour;
    uint public price;
    bool crowdsaleClosed = false;
    token public tokenReward;

    event GoalReached(address _beneficiary, uint _amountRaised);
    event CrowdSaleClosed(address _beneficiary, uint _amountRaised);
    event BurnedExcessTokens(address _beneficiary, uint _amountBurned);
    event Refunded(address _investor, uint _depositedValue);
    event FundTransfer(address _backer, uint _amount, bool _isContribution);
    event TokenPurchase(address _backer, uint _amount, uint _tokenAmt);

    /* data structure to hold information about campaign contributors */
    mapping(bytes32 => uint) public bonusSchedule;
    mapping(address => uint256) public balances;
    mapping(address => uint256) public investorTokens;

    /*  at initialization, setup the owner */
    function VeteranCoinSale(address _fundManager, uint _weiBonusPrice1, uint _weiBonusPrice2,
    uint _weiBonusPrice3, uint _weiBonusPrice4, token addressOfTokenUsedAsReward ) {
        if(_fundManager != 0){
            owner = _fundManager;
        }
        tokenReward = token(addressOfTokenUsedAsReward);
        tokenSold = 0;
        amountRaised = 0;
        startDate = now + 4 minutes;
        deadline = startDate + 15 minutes;
        weekTwo = startDate + 5 minutes;
        weekThree = startDate + 7 minutes;
        weekFour = startDate + 9 minutes;
        bonusSchedule["week1"] = _weiBonusPrice1;
        bonusSchedule["week2"] = _weiBonusPrice2;
        bonusSchedule["week3"] = _weiBonusPrice3;
        bonusSchedule["week4"] = _weiBonusPrice4;
        price = bonusSchedule["week1"];
        require(startDate < deadline);
        require(weekTwo < weekThree);
        require(weekThree < weekFour);
    }

    /* The function without name is the default function that is called whenever anyone sends funds to a contract */
    function () payable releaseTheHounds {
        require (!crowdsaleClosed);
        uint amount = msg.value;
        balances[msg.sender]  = balances[msg.sender].add(amount);
        //balances[msg.sender] += amount;
        uint256 tokens = amount.div(price).mul(1 ether);
        //uint256 tokens = (amount / price) * 1 ether;
        amountRaised = amountRaised.add(amount);
        //amountRaised += amount;
        tokenReward.transfer(msg.sender, tokens);
        FundTransfer(msg.sender, amount, true);
        TokenPurchase(msg.sender, amount, tokens);
        investorTokens[msg.sender] = investorTokens[msg.sender].add(tokens);
        //investorTokens[msg.sender] = tokens;
        tokenSold = tokenSold.add(tokens);
        //tokenSold += tokens;
        checkFundingGoalReached();
        checkDeadlineExpired();
        adjustBonusPrice();
    }

    function refund(address investor) onlyOwner {
        uint tokens = investorTokens[investor];
        require(tokenReward.transferFrom(investor, owner, tokens));
        investorTokens[investor] = 0;
        uint256 depositedValue = balances[investor];
        balances[investor] = 0;
        investor.transfer(depositedValue);
        Refunded(investor, depositedValue);
    }

    modifier afterDeadline() { if (now >= deadline) _; }

    modifier releaseTheHounds(){ if (now >= startDate) _;}

    function setPrice(uint256 _newSellPrice) onlyOwner{
        price = _newSellPrice;
    }

    function adjustBonusPrice() private {
        if (now >= weekTwo && now < weekThree){
            price = bonusSchedule["week2"];
        }
        if (now >= weekThree && now < weekFour){
            price = bonusSchedule["week3"];
        }
        if(now >= weekFour){
            price = bonusSchedule["week4"];
        }
    }

    function checkFundingGoalReached() private {
        uint amount = tokenReward.balanceOf(this);
        if(amount == 0){
            crowdsaleClosed = true;
            GoalReached(owner, amountRaised);
        }
    }

    function checkDeadlineExpired() private{
        if(now >= deadline){
            crowdsaleClosed = true;
            autoBurn();
            CrowdSaleClosed(owner, amountRaised);
        }
    }

    function autoBurn() private {
        uint256 burnPile = tokenReward.balanceOf(this).sub(tokenSold);
        //uint256 burnPile = tokenReward.balanceOf(this) - tokenSold;
        require(burnPile > 0);
        tokenReward.burn(burnPile);
        BurnedExcessTokens(owner, burnPile);

    }

    function safeWithdrawal() onlyOwner{
        uint256 balance = this.balance;
        if(owner.send(balance)){
            FundTransfer(owner,balance,false);
        }
    }

    function safeBurn() onlyOwner {
        uint256 burnPile = tokenReward.balanceOf(this).sub(tokenSold);
        //uint256 burnPile = tokenReward.balanceOf(this) - tokenSold;
        require(burnPile > 0);
        tokenReward.burn(burnPile);
        BurnedExcessTokens(owner, burnPile);
    }

}
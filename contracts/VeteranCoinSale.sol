pragma solidity ^0.4.11;

/**
* Copyright 2017 Veterapreneur
*
* Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
* documentation files (the "Software"), to deal in the Software without restriction, including without limitation the
* rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
* permit persons to whom the Software is furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in all copies or substantial portions of
* the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
* WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
* COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
* OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*
*
*/


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

    uint private tokenSold;
    uint private startDate;
    uint private deadline;
    uint private weekTwo;
    uint private weekThree;
    uint private weekFour;
    // how many token units a buyer gets per wei
    uint private rate;
    bool private crowdsaleClosed = false;
    token private tokenReward;

    event GoalReached(address _beneficiary);
    event CrowdSaleClosed(address _beneficiary);
    event BurnedExcessTokens(address _beneficiary, uint _amountBurned);
    event Refunded(address _investor, uint _depositedValue);
    event FundTransfer(address _backer, uint _amount, bool _isContribution);
    event TokenPurchase(address _backer, uint _amount, uint _tokenAmt);
    event TokenClaim(address _backer, uint _tokenAmt);
    event BonusRateChange(uint _rate);

    /* data structure to hold information about campaign contributors */

    // how many token units a buyer gets per wei
    mapping(bytes32 => uint) private bonusSchedule;
    mapping(address => uint256) private balances;
    mapping(address => uint256) private investorTokens;

    /*  at initialization, setup the owner */
    function VeteranCoinSale(address _fundManager, uint _week1BonusRate, uint _week2BonusRate,
    uint _week3BonusRate, uint _week4BonusRate, token addressOfTokenUsedAsReward ) {
        if(_fundManager != 0){
            owner = _fundManager;
        }
        tokenReward = token(addressOfTokenUsedAsReward);

        tokenSold = 0;
        startDate = now;
        deadline = startDate + 15 minutes;
        weekTwo = startDate + 5 minutes;
        weekThree = startDate + 7 minutes;
        weekFour = startDate + 9 minutes;

        bonusSchedule["week1"] =  _week1BonusRate;
        bonusSchedule["week2"] =  _week2BonusRate;
        bonusSchedule["week3"] =  _week3BonusRate;
        bonusSchedule["week4"] =  _week4BonusRate;

        //sanity checks
        require(startDate < deadline);
        require(weekTwo < weekThree);
        require(weekThree < weekFour);

        require( bonusSchedule["week1"] < bonusSchedule["week2"]);
        require( bonusSchedule["week2"] < bonusSchedule["week3"]);
        require( bonusSchedule["week3"] < bonusSchedule["week4"]);

        // set rate according to bonus schedule for week 1
        rate = bonusSchedule["week1"];

    }

    modifier afterDeadline() { if (now >= deadline) _; }
    modifier releaseTheHounds(){ if (now >= startDate) _;}

    /**
    * @dev tokens must be claimed() after the sale
    */
    function claimToken() afterDeadline {
        uint tokens = investorTokens[msg.sender];
        if(tokens > 0){
            investorTokens[msg.sender] = 0;
            tokenReward.transfer(msg.sender, tokens);
            TokenClaim(msg.sender, tokens);
        }
    }

    /**
     @dev buy tokens here, claim tokens after sale ends!
    */
    function buyTokens() payable external releaseTheHounds {
        require (!crowdsaleClosed);
        uint weiAmount = msg.value;

        balances[msg.sender]  = balances[msg.sender].add(weiAmount);
        uint256 tokens = weiAmount.mul(rate);

        FundTransfer(msg.sender, weiAmount, true);
        TokenPurchase(msg.sender, weiAmount, tokens);
        investorTokens[msg.sender] = investorTokens[msg.sender].add(tokens);
        tokenSold = tokenSold.add(tokens);

        checkFundingGoalReached();
        checkDeadlineExpired();
        adjustBonusPrice();
    }

    /**
    * @dev tokens must be claimed() here, then approved() in coin contract to this address by tokenowner prior to refund
    * @param _investor The amount to be transferred.
    */
    function refund(address _investor, uint _tokens) onlyOwner afterDeadline {
        require(tokenReward.transferFrom(_investor, owner, _tokens));
        uint256 depositedValue = balances[_investor];
        balances[_investor] = 0;
        tokenSold = tokenSold.sub(_tokens);
        _investor.transfer(depositedValue);
        Refunded(_investor, depositedValue);
    }

    function setRate(uint256 _newRate) onlyOwner{
        rate = _newRate;
    }

    /**
    *   @dev make two checks before writing new rate
    */
    function adjustBonusPrice() private {
        if (now >= weekTwo && now < weekThree){
            if(rate != bonusSchedule["week2"]){
                rate = bonusSchedule["week2"];
                BonusRateChange(rate);
            }
        }
        if (now >= weekThree && now < weekFour){
            if(rate != bonusSchedule["week3"]){
                rate = bonusSchedule["week3"];
                BonusRateChange(rate);
            }
        }
        if(now >= weekFour){
            if(rate != bonusSchedule["week4"]){
                rate = bonusSchedule["week4"];
                BonusRateChange(rate);
            }
        }
    }

    function checkFundingGoalReached() private {
        uint amount = tokenReward.balanceOf(this);
        if(amount == 0){
            crowdsaleClosed = true;
            GoalReached(owner);
        }
    }

    function checkDeadlineExpired() private{
        if(now >= deadline){
            crowdsaleClosed = true;
            autoBurn();
            CrowdSaleClosed(owner);
        }
    }

    /**
    * @dev owner can safely withdraw contract value
    */
    function autoBurn() private {
        uint256 burnPile = tokenReward.balanceOf(this);
        if(burnPile > 0){
            tokenReward.burn(burnPile);
            BurnedExcessTokens(owner, burnPile);
        }
    }

    /**
     * @dev owner can safely burn remaining at any time closing sale
     */
    function safeBurn() onlyOwner {
        autoBurn();
        crowdsaleClosed = true;
        CrowdSaleClosed(owner);
    }

    /**
    * @dev owner can safely withdraw contract value
    */
    function safeWithdrawal() onlyOwner{
        uint256 balance = this.balance;
        if(owner.send(balance)){
            FundTransfer(owner,balance,false);
        }
    }

}
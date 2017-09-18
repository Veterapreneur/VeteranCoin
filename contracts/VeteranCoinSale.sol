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

    uint  tokenSold;
    uint  startDate;
    uint  deadline;
    uint  weekTwo;
    uint  weekThree;
    uint  weekFour;
    // how many token units a buyer gets per wei
    uint  rate;
    bool  crowdsaleClosed = false;
    token tokenReward;

    event GoalReached(address _beneficiary);
    event CrowdSaleClosed(address _beneficiary);
    event BurnedExcessTokens(address _beneficiary, uint _amountBurned);
    event Refunded(address _beneficiary, uint _depositedValue);
    event FundTransfer(address _backer, uint _amount, bool _isContribution);
    event TokenPurchase(address _backer, uint _amount, uint _tokenAmt);
    event TokenClaim(address _backer, uint _tokenAmt);
    event BonusRateChange(uint _rate);

    /* data structure to hold information about campaign contributors */

    // how many token units a buyer gets per wei
    mapping(bytes32 => uint)  bonusSchedule;
    mapping(address => uint256)  balances;
    mapping(address => uint256)  beneficiaryTokens;

    /*  at initialization, setup the owner */
    function VeteranCoinSale(address _fundManager, uint _week1BonusRate, uint _week2BonusRate,
    uint _week3BonusRate, uint _week4BonusRate, token addressOfTokenUsedAsReward ) {

        if(_fundManager != 0){
            owner = _fundManager;
        }

        require(_week1BonusRate > 0);
        require(_week2BonusRate > 0);
        require(_week3BonusRate > 0);
        require(_week4BonusRate > 0);

        bonusSchedule["week1"] =  _week1BonusRate;
        bonusSchedule["week2"] =  _week2BonusRate;
        bonusSchedule["week3"] =  _week3BonusRate;
        bonusSchedule["week4"] =  _week4BonusRate;

        require( bonusSchedule["week1"] > bonusSchedule["week2"]);
        require( bonusSchedule["week2"] > bonusSchedule["week3"]);
        require( bonusSchedule["week3"] > bonusSchedule["week4"]);

        tokenReward = token(addressOfTokenUsedAsReward);

        tokenSold = 0;
        startDate = now;
        // todo move the times into ctr
        deadline = startDate + 15 minutes;
        weekTwo = startDate + 5 minutes;
        weekThree = startDate + 7 minutes;
        weekFour = startDate + 9 minutes;

        //sanity checks
        require(startDate < deadline);
        require(weekTwo < weekThree);
        require(weekThree < weekFour);

        // set rate according to bonus schedule for week 1
        rate = bonusSchedule["week1"];

    }

    modifier afterDeadline() { if (now >= deadline) _; }
    modifier releaseTheHounds(){ if (now >= startDate) _;}

    /**
    * @dev tokens must be claimed() after the sale
    */
    function claimToken() public afterDeadline {
        uint tokens = beneficiaryTokens[msg.sender];
        if(tokens > 0){
            beneficiaryTokens[msg.sender] = 0;
            tokenReward.transfer(msg.sender, tokens);
            TokenClaim(msg.sender, tokens);
        }
    }

    /**
    *  @dev buy tokens here, claim tokens after sale ends!
    */
    function buyTokens() payable releaseTheHounds {
        require (!crowdsaleClosed);
        require (msg.sender != 0x0);
        uint weiAmount = msg.value;

        balances[msg.sender]  = balances[msg.sender].add(weiAmount);
        uint256 tokens = weiAmount.mul(rate);

        FundTransfer(msg.sender, weiAmount, true);
        TokenPurchase(msg.sender, weiAmount, tokens);
        beneficiaryTokens[msg.sender] = beneficiaryTokens[msg.sender].add(tokens);
        tokenSold = tokenSold.add(tokens);

        checkFundingGoalReached();
        checkDeadlineExpired();
        adjustBonusPrice();
    }

    /**
     *
     *    @dev balances of wei sent to this contract
     *    @param _beneficiary number of tokens prior to claim
     *
     */
    function tokenBalanceOf(address _beneficiary) public constant returns (uint256 balance){
        return beneficiaryTokens[_beneficiary];
    }

    /**
     *
     *   @dev balances of wei sent this contract currently holds
     *    @param _beneficiary how much wei this address sent to contract
     */
    function balanceOf(address _beneficiary) public constant returns (uint256 balance){
        return balances[_beneficiary];
    }

    /**
    * @dev tokens must be claimed() first, then approved() in coin contract to owner address by "token holder" prior to refund
    * @param _beneficiary The investor getting the refund
    * @param _tokens number of be transferred.
    */
    function refund(address _beneficiary, uint _tokens) public onlyOwner afterDeadline {
        require(beneficiaryTokens[_beneficiary] == 0);
        require(tokenReward.transferFrom(_beneficiary, owner, _tokens));
        uint256 depositedValue = balances[_beneficiary];
        balances[_beneficiary] = 0;
        tokenSold = tokenSold.sub(_tokens);
        _beneficiary.transfer(depositedValue);
        Refunded(_beneficiary, depositedValue);
    }
    /*
    * @dev set a new rate
    * @param how many token units a buyer gets per wei
    */
    function setRate(uint256 _newRate) public onlyOwner{
        require(_newRate >0);
        rate = _newRate;
    }

    /**
    *   @dev make two checks before writing new rate
    */
    function adjustBonusPrice() internal {
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

    /**
     * @dev when # token balance is 0, it's over
     *
     */
    function checkFundingGoalReached() internal {
        if(tokenReward.balanceOf(this) == 0){
            crowdsaleClosed = true;
            GoalReached(owner);
        }
    }

    function checkDeadlineExpired() internal {
        if(now >= deadline){
            crowdsaleClosed = true;
            CrowdSaleClosed(owner);
            autoBurn();
        }
    }

    /**
    * @dev auto burn the tokens
    * throws exception if balance < tokensold
    */
    function autoBurn() internal {
        uint totalSale = tokenSold + tokenReward.balanceOf(this);
        uint256 burnPile = totalSale - tokenSold;
        if(burnPile > 0){
            tokenReward.burn(burnPile);
            BurnedExcessTokens(owner, burnPile);
        }
    }

    /**
     * @dev owner can safely burn remaining at any time closing sale
     */
    function safeBurn() public onlyOwner {
        crowdsaleClosed = true;
        CrowdSaleClosed(owner);
        autoBurn();
    }

    /**
    * @dev owner can safely withdraw contract value
    */
    function safeWithdrawal() public onlyOwner{
        uint256 balance = this.balance;
        if(owner.send(balance)){
            FundTransfer(owner,balance,false);
        }
    }

    // @return true if crowdsale event has ended
    function hasEnded() public constant returns (bool) {
        return crowdsaleClosed;
    }

}
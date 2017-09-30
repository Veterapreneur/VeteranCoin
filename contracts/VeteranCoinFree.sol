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


contract VeteranCoinFree is owned {

    using SafeMath for uint256;

    uint  public tokensGiven;
    uint  public startDate;
    uint  public endDate;
    bool  giveAwayOpen;
    token tokenReward;

    event GiveAwayClosed();
    event OpenGiveAway();
    event FundTransfer(address _backer, uint _amount, bool _isContribution);
    event FreeTokens(address _backer, uint _tokenAmt);
    event Refunded(address _beneficiary, uint _depositedValue);
    event BurnedExcessTokens(address _beneficiary, uint _amountBurned);

    mapping(address => uint256)  balances;

    modifier releaseTheHounds(){ if (now >= startDate) _;}
    modifier isGiveAwayOpen(){ if (giveAwayOpen) _;}

    function VeteranCoinFree(token _addressOfTokenReward){
        startDate = now;
        endDate = now + 1 years;
        tokenReward = _addressOfTokenReward;
        tokensGiven = 0;
        giveAwayOpen = false;
    }

    /**
    *  @dev donations, no tokens only thanks!
    */
    function donation() payable {
        require (msg.sender != 0x0);
        balances[msg.sender] = balances[msg.sender].add(msg.value);
        FundTransfer(msg.sender, msg.value, true);
    }

    /**
    *
    *   @dev Everyone can get 10 free tokens per call, enjoy
    */
    function tokenGiveAway() releaseTheHounds isGiveAwayOpen{
        uint256 tokens = 10 * 1 ether;
        tokensGiven = tokensGiven.add(tokens);
        tokenReward.transfer(msg.sender, tokens);
        checkGivenAway();
    }

    /**
    *   @dev refund any of the donations made to us
    *
    */
    function refundDonation(address _beneficiary) public onlyOwner{
        uint256 depositedValue = balances[_beneficiary];
        require(depositedValue > 0);
        balances[_beneficiary] = 0;
        _beneficiary.transfer(depositedValue);
        Refunded(_beneficiary, depositedValue);
    }

    /**
    *
    *   @dev close the give away when the MVP is nigh, or we are out of tokens!
    */
    function closeGiveAway() public onlyOwner{
        giveAwayOpen = false;
        GiveAwayClosed();
    }

    function openGiveAway() public onlyOwner{
        giveAwayOpen = true;
        OpenGiveAway();
    }

    /**
     * @dev when token's sold = 0, it's over
     *
     */
    function checkGivenAway() internal {
        if(tokenReward.balanceOf(this) == 0){
            giveAwayOpen = false;
            GiveAwayClosed();
        }
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

    // @return true if crowdsale is still going on
    function giveAwayInProgress() public constant returns (bool) {
        return giveAwayOpen;
    }

    /**
     * @dev auto burn the tokens
     *
     */
    function autoBurn() public onlyOwner{
        giveAwayOpen = false;
        uint256 burnPile = tokenReward.balanceOf(this);
        if(burnPile > 0){
            tokenReward.burn(burnPile);
            BurnedExcessTokens(owner, burnPile);
        }
    }

}

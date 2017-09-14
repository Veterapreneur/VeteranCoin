var VeteranCoin = artifacts.require("./VeteranCoin.sol");

contract('VeteranCoin', function(accounts){

    var acct0 = '0xe47591f5f16ee591b6d3294d012fc037d10ab805';
    var acct2 = '0x878db6d21614cc5170757c3f1f77c4f0cf2feeae';
    var acct3 = '0x707a909e5a2029a3f420650312639f089ed9cddb';

 it("Initial balance Test", function(){
    return VeteranCoin.deployed().then(function(instance){
        //console.log('Owner account is : ' + accounts[0]);
        return instance.balanceOf.call(accounts[0]);
    }).then(function (balance){
      //console.log('Initial balance is: ' + balance.valueOf());
      assert.equal(balance.toNumber(), 1E19, "1E19 wasn't in the first account");
    });
 });


 it("Approve and Allow Test, Provisioing", function(){
     var vet;
     var truthiness;
     var balance;
     return VeteranCoin.deployed().then(function(instance){
         vet = instance;
         return vet.approve(accounts[1], 1E18);
     }).then(function(){
         return vet.allowance.call(accounts[0], accounts[1]);
     }).then(function (datNewBalance){
         balance = datNewBalance.toNumber();
         //console.log('Account balance is ' + balance );
         assert.equal(balance, 1E18, "Incorrect amount provisioned!");

     });
 });

    it("transfer from acct0 by acc2 to acct3 from test", function(){
        var vet;
        return VeteranCoin.deployed().then(function(instance){
            vet = instance;
            return vet.approve(acct2, 2E18);
        }).then(function(){
            return vet.transferFrom(acct0, acct3, 2E18, {from: acct2});
        }).then(function(){
            return vet.balanceOf.call(acct3);
        }).then(function(badderBoatBalance){
            assert.equal(badderBoatBalance.toNumber(), 2E18, "Transfer amount wrong!");
        });
    });

    it("transfer from acct3 back to acct0 and then back to acct3", function() {
        var vet;
        return VeteranCoin.deployed().then(function (instance) {
            vet = instance;
            return vet.transfer(acct0, 2E18, {from: acct3});
        }).then(function () {
            return vet.balanceOf.call(acct0);
        }).then(function (baln) {
            assert.equal(baln.toNumber(), 1E19, "Transfer amount wrong!");
            return vet.transfer(acct3, 2E18);
        }).then(function(){
            return vet.balanceOf.call(acct3);
        }).then(function(abal){
            assert.equal(abal.toNumber(), 2E18, "Transfer amount wrong!");
        });
    });

    it("test burn check balance", function(){
        var vet;
        return VeteranCoin.deployed().then(function(instance){
            vet = instance;
            return vet.burn(8E18);
        }).then(function(tx){
            console.log("Print events");
            console.log(tx.logs[0]);
            return vet.balanceOf.call(acct0);
        }).then(function(boatBigDogBalance){
            //console.log("Balance " + boatBigDogBalance.toNumber());
            assert.equal(boatBigDogBalance.toNumber(), 0, "nope");
        });
    });

});
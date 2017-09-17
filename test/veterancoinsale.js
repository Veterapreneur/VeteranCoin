

const  VeteranCoin = artifacts.require("./VeteranCoin.sol");
const  VeteranCoinSale = artifacts.require("./VeteranCoinSale.sol");

contract('VeteranCoinSale', function(accounts){
    var sale;
    var coin;
    it("Init a sale", function () {
       return VeteranCoinSale.deployed().then(function(instance){
           sale = instance;
       }).then(function(){
           return VeteranCoin.deployed().then(function(instance){
               coin = instance;
           });
       }).then(function(){
           return coin.balanceOf.call(accounts[0]);
       }).then(function(balance){
           assert.equal(balance.toNumber(), 1E19, "balance incorrect");
           return coin.transfer(sale.address, 1E19);
       }).then(function(tx){
           console.log(tx.logs[0]);
           return coin.balanceOf.call(sale.address);
       }).then(function(balance1){
           assert.equal(balance1.toNumber(), 1E19, "sale contract doesn't have the coins");

           /**
           web3.eth.sendTransaction({from: accounts[3], to: sale.address, value: 152E13}, function(err1,resp1){
               if(err1){
                   console.log("Error: " + err1);
               }
               else{
                   console.log("Transaction: " + resp1);
               }

           });
            */
       });
    });

});
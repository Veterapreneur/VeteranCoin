

const  VeteranCoin = artifacts.require("./VeteranCoin.sol");
const  VeteranCoinSale = artifacts.require("./VeteranCoinSale.sol");
const VeteranCoinFree = artifacts.require("./VeteranCoinFree.sol");

/**
 * Use the deployed contract constructor from deploy_veterancoinsale.js
 */
contract('VeteranCoinSale', function(accounts){

    var sale;
    var coin;
    var accts2 = accounts[2];
    var accts3 = accounts[3];

    it("Init a sale do a single purchase", function () {
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
           //console.log(tx.logs[0]);
           return coin.balanceOf.call(sale.address);
       }).then(function(balance1){
           //console.log("sale coin balance: " + balance1.toNumber());
           assert.equal(balance1.toNumber(), 1E19, "sale contract doesn't have the coins");
           return sale.openSale();
       }).then(function(tx){
           console.log(tx.logs[0]);
           return sale.buyTokens({from: accts3, value: 15E14});
       }).then(function(tx2){
          //console.log(tx2.logs[0]);
           return sale.balanceOf.call(accts3);
       }).then(function(balance2){
           assert.equal(balance2.toNumber(), 15E14, "Incorrect ether balance sent to contract");
           return sale.tokenBalanceOf.call(accts3);
       }).then(function(tokenBalance){
           assert.equal(tokenBalance.toNumber(), 9.99E17, "Incorrect number of tokens reserved");
       });
    });

});

contract('VeteranCoinFree', function(accounts){
   var coin;
   var giveAway;
    it("Init a coin and a giveaway", function(){
       return VeteranCoin.new(1E25, 0).then(function(instance){
           coin = instance;
       }).then(function () {
           return VeteranCoinFree.new(coin.address).then(function(instance0){
               giveAway = instance0;
           });
       }).then(function(){
           return coin.balanceOf.call(accounts[0]);
       }).then(function(balance){
           assert.equal(balance.toNumber(), 1E25, "coin contract balance incorrect");
       })
    });

    it("transfer to the giveaway, check its closed, open it and check it", function(){
        return coin.transfer(giveAway.address, 2E20).then(function(tx){
            return coin.balanceOf.call(giveAway.address);
        }).then(function(bal){
            assert.equal(bal.toNumber(), 2E20, "contract has wrong number tokens");
            // token giveaway closed
            return giveAway.giveAwayInProgress.call();
        }).then(function(isOpen){
            assert.equal(false, isOpen);
            //open giveaway
            return giveAway.openGiveAway();
        }).then(function(tx){
            return giveAway.giveAwayInProgress.call();
        }).then(function(isOpen){
            assert.equal(true, isOpen);
        });
    });

    it("Get some tokens from the giveaway, check all the balances are correctly updated", function(){
       return giveAway.tokenGiveAway({from:accounts[3]}).then(function (tx) {
           return coin.balanceOf.call(accounts[3]);
       }).then(function(bal){
           assert.equal(bal.toNumber(), 10E18);
           return coin.balanceOf.call(giveAway.address);
       }).then(function(bal){
           assert.equal(bal.toNumber(), 1.90E20);
       });
    });

    it("take a donation in the giveaway", function(){
        const initialBalance = web3.eth.getBalance(web3.eth.accounts[1]);
        console.log("Balance account[1] " + web3.fromWei(initialBalance).toString());

        web3.eth.sendTransaction({from: accounts[1], to: giveAway.address, value: web3.toWei(1)});
        //console.log("Transaction id: " + tx);
        const finalBalance = web3.eth.getBalance(giveAway.address);
        // could use web3.fromWei to get the 'wei'
        assert.equal(1E18, finalBalance.toNumber());
        console.log("Contract Giveaway donations : " + web3.fromWei(finalBalance).toString())
    });

    it("Give a refund from the giveaway", function(){
        return giveAway.balanceOf.call(accounts[1]).then(function(bal){
            assert.equal(1E18, bal.toNumber());
            return giveAway.refundDonation(accounts[1]);
        }).then(function (tx) {
            //console.log(tx.logs[0]);
            return giveAway.balanceOf(accounts[1]);
        }).then(function(bal){
            assert.equal(0, bal.toNumber());
        });
    });

});

/**
 *  create our own *new instances of the VeteranCoin and Sale for new tests
 */
contract('VeteranCoinSale', function(accounts){

    var sale;
    var coin;

    it("Start another contract w bigger amounts", function(){
        return VeteranCoin.new(10E19, 0).then(function(instance0){
            coin = instance0;
        }).then(function(){
            return VeteranCoinSale.new(0, 666, 625, 588, 556, coin.address).then(function(instance1){
                sale = instance1;
            });
        }).then(function(){
            return coin.balanceOf.call(accounts[0]);
        }).then(function(balance){
            assert.equal(balance.toNumber(), 10E19, "coin contract balance incorrect");
        });
    });

    it("Send crowdsale contract all coins!", function(){
        return coin.transfer(sale.address, 10E19).then(function(tx){
            //console.log(tx.logs[0]);
            return coin.balanceOf.call(sale.address);
        }).then(function(bal){
            assert.equal(bal.toNumber(), 10E19, "contracts didn't get right amt of tokens");
            return coin.balanceOf.call(accounts[0]);
        }).then(function(bal){
            assert.equal(bal.toNumber(), 0, "contract has every token");
        });
    });

    it("Check status of sale before started", function(){
       return sale.saleInProgress.call().then(function(ended){
           assert.equal(false, ended.valueOf());
           return sale.openSale();
       }).then(function(tx){
           console.log(tx.logs[0]);
       });
    });

    it("Buy some tokens then burn remaining, closes sale", function(){
        return sale.buyTokens({from: accounts[3], value: 15E14}).then(function(tx){
            console.log(tx.logs[0]);
            return sale.balanceOf.call(accounts[3]);
        }).then(function(balance) {
            assert.equal(balance.toNumber(), 15E14, "Transfer amount wrong!");
            return sale.tokenBalanceOf.call(accounts[3]);
        }).then(function(tokBal){
            assert.equal(tokBal.toNumber(), 9.99E17, "Incorrect number of tokens");
            return sale.autoBurn();
        }).then(function(tx1){
            //console.log(tx1.logs[1]);
            //console.log("Sale contract: " + sale.address);
            return coin.balanceOf.call(sale.address);
        }).then(function(zBal){
            assert.equal(zBal.toNumber(), 9.99E17, "Wrong number of tokens are left!");
        });
        // remove the fallback function so no ether can be sent otherwise, how do we pass a test when we want/expect a failure in truffle?
        /**
        web3.eth.sendTransaction({from: accounts[3], to: sale.address, value: 15E14}, function(err1,resp1){
            if(err1){
                console.log("Error: " + err1);
            }
            else{
                console.log("Transaction: " + resp1);
            }
        });
         */
    });

    it("Check sale is closed, withdraw my token and check I got it", function(){
        return sale.saleInProgress.call().then(function(ended){
            assert.equal(false, ended.valueOf());
            return sale.tokenBalanceOf.call(accounts[3]);
        }).then(function(balance){
            assert.equal(balance.toNumber(), 9.99E17, "Tokens bought and held by contract are incorrect!");
            return sale.claimToken({from: accounts[3]});
        }).then(function(tx){
            //console.log(tx.logs[0]);
            return sale.tokenBalanceOf.call(accounts[3]);
        }).then(function(zBal){
            assert.equal(zBal.toNumber(), 9.99E17, "Tokens are not left in this contract account! (not deadline)");
            return coin.balanceOf.call(sale.address);
        }).then(function(cBal){
            assert.equal(cBal.toNumber(), 9.99E17, "Tokens needed to clain not there!");
        });
    });

});

var VeteranCoin = artifacts.require("./VeteranCoin.sol");
var VeteranCoinSale = artifacts.require("./VeteranCoinSale.sol");


module.exports = function(deployer){
    deployer.deploy(VeteranCoin, 1E19, 0).then(function(){
        return deployer.deploy(VeteranCoinSale, 0, 666, 625, 588, 556, VeteranCoin.address);
    });
}

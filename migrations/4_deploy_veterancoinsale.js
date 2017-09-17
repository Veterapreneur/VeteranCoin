var VeteranCoin = artifacts.require("./VeteranCoin.sol");
var VeteranCoinSale = artifacts.require("./VeteranCoinSale.sol");


module.exports = function(deployer){
    deployer.deploy(VeteranCoin, 1E19, 0).then(function(){
        return deployer.deploy(VeteranCoinSale, 0, 152E13, 1615E12, 171E13, 1805E12, VeteranCoin.address);
    });
}

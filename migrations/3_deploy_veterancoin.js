var VeteranCoin  = artifacts.require("./VeteranCoin.sol");

module.exports = function(deployer){
    deployer.deploy(VeteranCoin, 1E19, 0);
};
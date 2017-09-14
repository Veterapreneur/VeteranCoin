/**
 * Created by cwyse on 9/10/17.
 */

var VeteranCoinSale = artifacts.require("./VeteranCoinSale.sol");

module.exports = function(deployer){
    deployer.deploy(VeteranCoinSale);
}

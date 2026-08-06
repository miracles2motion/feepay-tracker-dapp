// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/FeePay.sol";

contract DeployFeePay is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy the contract
        FeePay feePay = new FeePay();
        
        console.log("FeePay deployed to:", address(feePay));
        console.log("Owner:", feePay.owner());
        console.log("Treasurer:", feePay.treasurer());
        
        vm.stopBroadcast();
    }
}
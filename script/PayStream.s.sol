// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {PayStream} from "../src/PayStream.sol";

contract PayStreamScript is Script {
    PayStream public paystream;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        paystream = new PayStream();

        vm.stopBroadcast();
    }
}

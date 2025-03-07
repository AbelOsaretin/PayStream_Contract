// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {PayStream} from "../src/PayStream.sol";

contract PayStreamTest is Test {
    PayStream public paystream;

    address admin = makeAddr("admin");
    address employerAddr = makeAddr("employer");
    address employeeAddr = makeAddr("employee");

    function setUp() public {
        vm.startPrank(admin);
        paystream = new PayStream();
        vm.stopPrank();
    }

    function test_Register_Employer_Require_Statement() public {
        paystream.registerEmployer(employerAddr, "Abel");
        vm.expectRevert("Address already registered");
        paystream.registerEmployer(employerAddr, "Abel");
    }

    function test_Register_Employer_Success() public {
        paystream.registerEmployer(employerAddr, "Abel");
    }

    function test_Add_Employee_Modifier_And_Require_Statement() public {
        vm.expectRevert("Only employer can call this function");
        paystream.addEmployee(employeeAddr, "JohnDoe", 100000000000000000);
        vm.startPrank(employerAddr);
        test_Register_Employer_Success();
        paystream.addEmployee(employeeAddr, "JohnDoe", 100000000000000000);
        vm.expectRevert("Address already registered");
        paystream.addEmployee(employeeAddr, "JohnDoe", 100000000000000000);
        vm.stopPrank();
    }

    function test_Add_Employee_Success() public {
        vm.startPrank(employerAddr);
        test_Register_Employer_Success();
        paystream.addEmployee(employeeAddr, "JohnDoe", 100000000000000000);
        vm.stopPrank();
    }

    function test_Submit_Employee_KYC_Require_Statements() public {
        vm.expectRevert("Not registered as employee");
        paystream.submitEmployeeKYC("");
    }

    function test_update_Employee_Salary_Modifier_And_Success() public {
        test_Register_Employer_Success();
        vm.startPrank(employerAddr);
        vm.expectRevert("Employee does not exist");
        paystream.updateEmployeeSalary(employeeAddr, 10000000000);

        vm.stopPrank();
    }

    // function testFuzz_SetNumber(uint256 x) public {
    //     counter.setNumber(x);
    //     assertEq(counter.number(), x);
    // }
}

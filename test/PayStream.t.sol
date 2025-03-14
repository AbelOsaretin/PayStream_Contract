// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {PayStream} from "../src/PayStream.sol";

contract PayStreamTest is Test {
    PayStream public paystream;

    address admin = makeAddr("admin");
    address employerAddr = makeAddr("employer");
    address employerAddr2 = makeAddr("employer2");
    address payable employeeAddr = payable(makeAddr("employee"));
    address employeeAddr2 = makeAddr("employee2");

    function setUp() public {
        vm.startPrank(admin);
        paystream = new PayStream();
        vm.stopPrank();
    }

    // ========== EMPLOYER FUNCTIONS ==========

    function test_Register_Employer_Require_Statement() public {
        paystream.registerEmployer(employerAddr, "Abel");
        vm.expectRevert("Employer Address already registered");
        paystream.registerEmployer(employerAddr, "Abel");
    }

    function test_Register_Employer_Success() public {
        paystream.registerEmployer(employerAddr, "Abel");
        paystream.registerEmployer(employerAddr2, "KingB");
    }

    function test_Add_Employee_Modifier_And_Require_Statement() public {
        vm.expectRevert("Only employer can call this function");
        paystream.addEmployee(employeeAddr, "JohnDoe", 100000000000000000);
        vm.startPrank(employerAddr);
        test_Register_Employer_Success();
        paystream.addEmployee(employeeAddr, "JohnDoe", 100000000000000000);
        vm.expectRevert("Employee Address already registered");
        paystream.addEmployee(employeeAddr, "JohnDoe", 100000000000000000);
        vm.stopPrank();
    }

    function test_Add_Employee_Success() public {
        vm.startPrank(employerAddr);
        paystream.registerEmployer(employerAddr, "Abel");
        paystream.addEmployee(employeeAddr, "JohnDoe", 100000000000000000);
        vm.stopPrank();
    }

    function test_update_Employee_Salary_Modifiers() public {
        vm.startPrank(employerAddr);
        test_Register_Employer_Success();
        vm.expectRevert("Employee does not exist");
        paystream.updateEmployeeSalary(employeeAddr, 10000000000);
        paystream.addEmployee(employeeAddr, "JohnDoe", 100000000000000000);
        vm.stopPrank();

        vm.startPrank(employerAddr2);
        vm.expectRevert("Not the employer of this employee");
        paystream.updateEmployeeSalary(employeeAddr, 10000000000);
        vm.stopPrank();
    }

    function test_Update_Employee_Salary_Success() public {
        vm.startPrank(employerAddr);
        test_Register_Employer_Success();
        paystream.addEmployee(employeeAddr, "JohnDoe", 100000000000000000);
        vm.stopPrank();
    }

    function test_Set_Employee_Tax_Rate_Require_Statement() public {
        test_Add_Employee_Success();
        vm.startPrank(employerAddr);
        vm.expectRevert("Tax rate cannot exceed 100%");
        paystream.setEmployeeTaxRate(employeeAddr, 101);
        vm.stopPrank();
    }

    function test_Set_Employee_Tax_Rate_Success() public {
        test_Add_Employee_Success();
        vm.startPrank(employerAddr);
        paystream.setEmployeeTaxRate((employeeAddr), 10);
        vm.stopPrank();
    }

    // function test_Process_Payment_Success() public {
    //     test_Approve_Employee_KYC_Success();
    //     vm.startPrank(employerAddr);
    //     paystream.processPayment(payable(employeeAddr));
    //     vm.stopPrank();
    // }

    // function test_Process_Payment_Success() public {
    //     // Setup: Approve employee KYC first
    //     test_Approve_Employee_KYC_Success();

    //     // Get initial balances
    //     uint256 initialEmployeeBalance = address(employeeAddr).balance;

    //     // Set tax rate for the employee (assuming this hasn't been done yet)
    //     vm.startPrank(employerAddr);
    //     paystream.setEmployeeTaxRate(employeeAddr, 20); // 20% tax rate
    //     vm.stopPrank();

    //     // Get employee data using the tuple returned by the mapping
    //     (
    //         ,
    //         ,
    //         // address employeeAddress
    //         // string name
    //         uint256 salary, // uint256 lastPaymentDate
    //         // bool isActive
    //         // KYCStatus kycStatus
    //         // string kycDocumentHash
    //         ,
    //         ,
    //         ,
    //         ,
    //         uint256 taxRate
    //     ) = paystream.employees(employeeAddr);

    //     uint256 taxAmount = (salary * taxRate) / 100;
    //     uint256 expectedNetAmount = salary - taxAmount;

    //     // Process payment as employer with correct value
    //     vm.startPrank(employerAddr);
    //     paystream.processPayment{value: salary}(payable(employeeAddr));
    //     vm.stopPrank();

    //     // Verify employee received the correct amount
    //     assertEq(
    //         address(employeeAddr).balance,
    //         initialEmployeeBalance + expectedNetAmount,
    //         "Employee did not receive correct payment amount"
    //     );

    //     // Verify last payment date was updated - need to read the mapping again
    //     (
    //         ,
    //         ,
    //         ,
    //         // address employeeAddress
    //         // string name
    //         // uint256 salary
    //         uint256 lastPaymentDate, // bool isActive
    //         // KYCStatus kycStatus
    //         // string kycDocumentHash
    //         ,
    //         ,
    //         ,

    //     ) = // uint256 taxRate
    //         paystream.employees(employeeAddr);

    //     assertEq(
    //         lastPaymentDate,
    //         block.timestamp,
    //         "Last payment date not updated"
    //     );

    //     // Verify payment record was added to history
    //     // For the paymentHistory array, we need to destructure in the same way
    //     (
    //         address recordEmployer,
    //         address recordEmployee,
    //         uint256 recordAmount,
    //         uint256 recordTimestamp,
    //         uint256 recordTaxAmount
    //     ) = paystream.paymentHistory(0);

    //     assertEq(
    //         recordEmployer,
    //         employerAddr,
    //         "Payment record has incorrect employer"
    //     );
    //     assertEq(
    //         recordEmployee,
    //         employeeAddr,
    //         "Payment record has incorrect employee"
    //     );
    //     assertEq(
    //         recordAmount,
    //         expectedNetAmount,
    //         "Payment record has incorrect amount"
    //     );
    //     assertEq(
    //         recordTimestamp,
    //         block.timestamp,
    //         "Payment record has incorrect timestamp"
    //     );
    //     assertEq(
    //         recordTaxAmount,
    //         taxAmount,
    //         "Payment record has incorrect tax amount"
    //     );
    // }

    // ========== EMPLOYEE FUNCTIONS ==========

    function test_Submit_Employee_KYC_Require_Statements() public {
        vm.expectRevert("Not registered as employee");
        paystream.submitEmployeeKYC("");
        test_Add_Employee_Success();
        vm.startPrank(employeeAddr);
        paystream.submitEmployeeKYC("Hello");
        vm.expectRevert("KYC already submitted");
        paystream.submitEmployeeKYC("Hello");
        vm.stopPrank();
    }

    function test_Submit_Employee_KYC_Success() public {
        test_Add_Employee_Success();
        vm.startPrank(employeeAddr);
        paystream.submitEmployeeKYC("Hello");
        vm.stopPrank();
    }

    // ========== ADMIN FUNCTIONS ==========

    function test_Approve_Employee_KYC_Require_Statements() public {}

    function test_Approve_Employee_KYC_Success() public {
        test_Submit_Employee_KYC_Success();
        vm.startPrank(admin);
        paystream.approveEmployeeKYC(employeeAddr);
        vm.stopPrank();
    }
    // function testFuzz_SetNumber(uint256 x) public {
    //     counter.setNumber(x);
    //     assertEq(counter.number(), x);
    // }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title PayStream
 * @dev Smart contract implementation of a payroll system with KYC
 */
contract PayStream {
    // ========== STATE VARIABLES ==========

    address public owner;

    enum UserType {
        None,
        Employer,
        Employee
    }

    enum KYCStatus {
        NotSubmitted,
        Pending,
        Verified,
        Rejected
    }

    // Employee struct containing all employee-related data
    struct Employee {
        address employeeAddress;
        string name;
        uint256 salary;
        uint256 lastPaymentDate;
        bool isActive;
        KYCStatus kycStatus;
        string kycDocumentHash; // Hash of documents stored in IPFS
        uint256 taxRate;
    }

    // Employer struct containing employer data
    struct Employer {
        address employerAddress;
        string name;
        bool isVerified;
    }

    // Mapping from address to user type
    mapping(address => UserType) public userTypes;

    // Mapping of employer addresses to Employer structs
    mapping(address => Employer) public employers;

    // Mapping of employer addresses to their employees addresses
    mapping(address => address[]) public employerToEmployees;

    // Array of Employees
    Employee[] public employeesArray;

    // Counter for employeesArray
    uint256 employeesCounter;

    // Mapping of addresses to Employee structs
    mapping(address => Employee) public employees;

    // Payment records for audit trail
    struct PaymentRecord {
        address employer;
        address employee;
        uint256 amount;
        uint256 timestamp;
        uint256 taxAmount;
    }

    PaymentRecord[] public paymentHistory;

    // ========== EVENTS ==========

    event EmployerRegistered(address indexed employerAddress, string name);
    event EmployeeRegistered(
        address indexed employeeAddress,
        string name,
        address indexed employer
    );
    event KYCRequested(address indexed userAddress, UserType userType);
    event KYCVerified(address indexed userAddress, UserType userType);
    event KYCRejected(
        address indexed userAddress,
        UserType userType,
        string reason
    );
    event PaymentProcessed(
        address indexed employer,
        address indexed employee,
        uint256 amount,
        uint256 taxAmount
    );
    event SalaryUpdated(address indexed employee, uint256 newSalary);
    event TaxRateUpdated(address indexed employee, uint256 newTaxRate);

    // ========== MODIFIERS ==========

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyEmployer() {
        require(
            userTypes[msg.sender] == UserType.Employer,
            "Only employer can call this function"
        );
        require(employers[msg.sender].isVerified, "Employer not verified");
        _;
    }

    modifier employeeExists(address _employeeAddress) {
        require(
            userTypes[_employeeAddress] == UserType.Employee,
            "Employee does not exist"
        );
        require(employees[_employeeAddress].isActive, "Employee is not active");
        _;
    }

    modifier isEmployerOfEmployee(address _employeeAddress) {
        bool isEmployer = false;
        address[] memory employeeList = employerToEmployees[msg.sender];

        for (uint i = 0; i < employeeList.length; i++) {
            if (employeeList[i] == _employeeAddress) {
                isEmployer = true;
                break;
            }
        }

        require(isEmployer, "Not the employer of this employee");
        _;
    }

    // ========== CONSTRUCTOR ==========

    constructor() {
        owner = msg.sender;
    }

    // ========== EMPLOYER FUNCTIONS ==========

    /**
     * @dev Registers a new employer in the system
     * @param _name Name of the employer
     */
    function registerEmployer(
        address _employerAddr,
        string memory _name
    ) external {
        require(
            userTypes[_employerAddr] == UserType.None,
            "Employer Address already registered"
        );

        userTypes[_employerAddr] = UserType.Employer;

        Employer storage newEmployer = employers[_employerAddr];
        newEmployer.employerAddress = _employerAddr;
        newEmployer.name = _name;
        newEmployer.isVerified = true;

        emit EmployerRegistered(_employerAddr, _name);
    }

    /**
     * @dev Manage employees - add a new employee
     * @param _employeeAddress Address of the employee
     * @param _name Name of the employee
     * @param _salary Initial salary of the employee
     */
    function addEmployee(
        address _employeeAddress,
        string memory _name,
        uint256 _salary
    ) external onlyEmployer {
        require(
            userTypes[_employeeAddress] == UserType.None,
            "Employee Address already registered"
        );

        userTypes[_employeeAddress] = UserType.Employee;

        Employee storage newEmployee = employees[_employeeAddress];
        newEmployee.employeeAddress = _employeeAddress;
        newEmployee.name = _name;
        newEmployee.salary = _salary;
        newEmployee.isActive = true;
        newEmployee.kycStatus = KYCStatus.NotSubmitted;
        newEmployee.taxRate = 0; // Default tax rate, to be updated later

        employerToEmployees[msg.sender].push(_employeeAddress);
        employeesArray.push(newEmployee);
        employeesCounter = employeesCounter + 1;

        emit EmployeeRegistered(_employeeAddress, _name, msg.sender);
    }

    /**
     * @dev Update employee salary
     * @param _employeeAddress Address of the employee
     * @param _newSalary New salary amount
     */
    function updateEmployeeSalary(
        address _employeeAddress,
        uint256 _newSalary
    )
        external
        onlyEmployer
        employeeExists(_employeeAddress)
        isEmployerOfEmployee(_employeeAddress)
    {
        employees[_employeeAddress].salary = _newSalary;

        emit SalaryUpdated(_employeeAddress, _newSalary);
    }

    /**
     * @dev Set employee tax rate
     * @param _employeeAddress Address of the employee
     * @param _taxRate Tax rate percentage (e.g., 20 for 20%)
     */
    function setEmployeeTaxRate(
        address _employeeAddress,
        uint256 _taxRate
    )
        external
        onlyEmployer
        employeeExists(_employeeAddress)
        isEmployerOfEmployee(_employeeAddress)
    {
        require(_taxRate <= 100, "Tax rate cannot exceed 100%");

        employees[_employeeAddress].taxRate = _taxRate;

        emit TaxRateUpdated(_employeeAddress, _taxRate);
    }

    /**
     * @dev Process payment for a specific employee
     * @param _employeeAddress Address of the employee to pay
     */
    function processPayment(
        address payable _employeeAddress
    )
        external
        payable
        onlyEmployer
        employeeExists(_employeeAddress)
        isEmployerOfEmployee(_employeeAddress)
    {
        Employee storage employee = employees[_employeeAddress];

        require(
            employee.kycStatus == KYCStatus.Verified,
            "Employee KYC not verified"
        );

        uint256 salaryAmount = employee.salary;
        require(msg.value >= salaryAmount, "Insufficient funds sent");

        // Calculate tax
        uint256 taxAmount = (salaryAmount * employee.taxRate) / 100;
        uint256 netAmount = salaryAmount - taxAmount;

        // Process payment
        _employeeAddress.transfer(netAmount);

        // Update payment records
        employee.lastPaymentDate = block.timestamp;

        paymentHistory.push(
            PaymentRecord({
                employer: msg.sender,
                employee: _employeeAddress,
                amount: netAmount,
                timestamp: block.timestamp,
                taxAmount: taxAmount
            })
        );

        emit PaymentProcessed(
            msg.sender,
            _employeeAddress,
            netAmount,
            taxAmount
        );
    }

    /**
     * @dev View payment history for employer's employees
     * @return Array of payment records
     */
    function viewPaymentHistory()
        external
        view
        onlyEmployer
        returns (PaymentRecord[] memory)
    {
        uint256 count = 0;

        // Count relevant records
        for (uint256 i = 0; i < paymentHistory.length; i++) {
            if (paymentHistory[i].employer == msg.sender) {
                count++;
            }
        }

        // Create result array
        PaymentRecord[] memory result = new PaymentRecord[](count);
        uint256 index = 0;

        // Fill result array
        for (uint256 i = 0; i < paymentHistory.length; i++) {
            if (paymentHistory[i].employer == msg.sender) {
                result[index] = paymentHistory[i];
                index++;
            }
        }

        return result;
    }

    // ========== EMPLOYEE FUNCTIONS ==========

    /**
     * @dev Submit employee KYC document hash
     * @param _documentHash IPFS hash of the KYC documents
     */
    function submitEmployeeKYC(string memory _documentHash) external {
        require(
            userTypes[msg.sender] == UserType.Employee,
            "Not registered as employee"
        );
        require(
            employees[msg.sender].kycStatus == KYCStatus.NotSubmitted,
            "KYC already submitted"
        );

        employees[msg.sender].kycDocumentHash = _documentHash;
        employees[msg.sender].kycStatus = KYCStatus.Pending;

        emit KYCRequested(msg.sender, UserType.Employee);
    }

    /**
     * @dev View payment history for employee
     * @return Array of payment records
     */
    function viewMyPaymentHistory()
        external
        view
        returns (PaymentRecord[] memory)
    {
        require(userTypes[msg.sender] == UserType.Employee, "Not an employee");

        uint256 count = 0;

        // Count relevant records
        for (uint256 i = 0; i < paymentHistory.length; i++) {
            if (paymentHistory[i].employee == msg.sender) {
                count++;
            }
        }

        // Create result array
        PaymentRecord[] memory result = new PaymentRecord[](count);
        uint256 index = 0;

        // Fill result array
        for (uint256 i = 0; i < paymentHistory.length; i++) {
            if (paymentHistory[i].employee == msg.sender) {
                result[index] = paymentHistory[i];
                index++;
            }
        }

        return result;
    }

    // ========== ADMIN FUNCTIONS ==========

    /**
     * @dev Verify employee KYC
     * @param _employeeAddress Address of the employee
     */
    function approveEmployeeKYC(address _employeeAddress) external onlyOwner {
        require(
            userTypes[_employeeAddress] == UserType.Employee,
            "Not registered as employee"
        );
        require(
            employees[_employeeAddress].kycStatus == KYCStatus.Pending,
            "KYC not pending"
        );

        employees[_employeeAddress].kycStatus = KYCStatus.Verified;

        emit KYCVerified(_employeeAddress, UserType.Employee);
    }

    /**
     * @dev Reject employee KYC
     * @param _employeeAddress Address of the employee
     * @param _reason Reason for rejection
     */
    function rejectEmployeeKYC(
        address _employeeAddress,
        string memory _reason
    ) external onlyOwner {
        require(
            userTypes[_employeeAddress] == UserType.Employee,
            "Not registered as employee"
        );
        require(
            employees[_employeeAddress].kycStatus == KYCStatus.Pending,
            "KYC not pending"
        );

        employees[_employeeAddress].kycStatus = KYCStatus.Rejected;

        emit KYCRejected(_employeeAddress, UserType.Employee, _reason);
    }

    // Function to receive Ether. msg.data must be empty
    receive() external payable {}
}

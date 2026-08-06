// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/FeePay.sol";

contract FeePayTest is Test {
    FeePay public feePay;
    
    address public owner = address(0x1);
    address public admin = address(0x2);
    address public treasurer = address(0x3);
    address public student1 = address(0x4);
    address public student2 = address(0x5);
    address public randomUser = address(0x6);
    
    string constant USERNAME1 = "john_doe";
    string constant USERNAME2 = "jane_doe";
    string constant INSTITUTION = "MIT";
    string constant EMAIL1 = "john@example.com";
    string constant EMAIL2 = "jane@example.com";
    string constant PROFILE_HASH = "ipfs://QmExample";
    string constant ACADEMIC_SESSION = "2024-2025";
    
    function setUp() public {
        vm.startPrank(owner);
        feePay = new FeePay();
        feePay.addAdmin(admin);
        feePay.addTreasurer(treasurer);
        vm.stopPrank();
        
        vm.deal(student1, 10 ether);
        vm.deal(student2, 10 ether);
    }
    
    // ============================================
    // HELPER FUNCTIONS
    // ============================================
    
    function _registerStudent(address wallet, string memory username, string memory email) internal {
        vm.startPrank(wallet);
        feePay.registerStudent(
            username,
            INSTITUTION,
            email,
            PROFILE_HASH
        );
        vm.stopPrank();
    }
    
    function _payFee(address wallet, FeePay.FeeType feeType) internal {
        uint256 amount = feePay.getFeeAmount(feeType);
        vm.startPrank(wallet);
        feePay.payFee{value: amount}(
            feeType,
            FeePay.Semester.FIRST,
            ACADEMIC_SESSION,
            "0x1234567890abcdef",
            "Test payment"
        );
        vm.stopPrank();
    }
    
    function _getFeeSchedule(FeePay.FeeType feeType) internal view returns (FeePay.FeeSchedule memory) {
        (FeePay.FeeType ft, uint256 amount, bool isActive, string memory description) = feePay.feeSchedules(feeType);
        return FeePay.FeeSchedule({
            feeType: ft,
            amount: amount,
            isActive: isActive,
            description: description
        });
    }
    
    function _getStudent(address wallet) internal view returns (
        string memory studentId,
        string memory username,
        string memory institution,
        string memory email,
        address walletAddress,
        uint256 registrationDate,
        uint256 lastLogin,
        FeePay.AccountStatus status,
        string memory profileHash
    ) {
        (studentId, username, institution, email, walletAddress, registrationDate, lastLogin, status, profileHash) = feePay.students(wallet);
    }
    
    // ============================================
    // INITIALIZATION TESTS
    // ============================================
    
    function test_Initialization() public {
        assertEq(feePay.owner(), owner);
        assertEq(feePay.treasurer(), owner);
        assertTrue(feePay.admins(owner));
        assertTrue(feePay.treasurers(owner));
        assertFalse(feePay.paused());
        assertEq(feePay.requiredConfirmations(), 12);
        assertEq(feePay.dailyWithdrawalLimit(), 5 ether);
        assertEq(feePay.getStudentCount(), 0);
    }
    
    function test_InitialFeeSchedules() public {
        uint256 expectedFeeTypes = 7;
        uint256 activeCount = 0;
        
        for (uint i = 0; i < 7; i++) {
            FeePay.FeeType feeType = FeePay.FeeType(i);
            FeePay.FeeSchedule memory schedule = _getFeeSchedule(feeType);
            if (schedule.isActive) {
                activeCount++;
            }
            assertGt(schedule.amount, 0);
            assertTrue(bytes(schedule.description).length > 0);
        }
        
        assertEq(activeCount, expectedFeeTypes);
        
        assertEq(feePay.getFeeAmount(FeePay.FeeType.TUITION), 0.05 ether);
        assertEq(feePay.getFeeAmount(FeePay.FeeType.HOSTEL), 0.025 ether);
        assertEq(feePay.getFeeAmount(FeePay.FeeType.LIBRARY), 0.01 ether);
        assertEq(feePay.getFeeAmount(FeePay.FeeType.LAB), 0.015 ether);
        assertEq(feePay.getFeeAmount(FeePay.FeeType.SPORTS), 0.008 ether);
        assertEq(feePay.getFeeAmount(FeePay.FeeType.EXAMINATION), 0.012 ether);
    }
    
    // ============================================
    // STUDENT REGISTRATION TESTS
    // ============================================
    
    function test_RegisterStudent() public {
        vm.startPrank(student1);
        feePay.registerStudent(
            USERNAME1,
            INSTITUTION,
            EMAIL1,
            PROFILE_HASH
        );
        vm.stopPrank();
        
        assertTrue(feePay.isRegistered(student1));
        assertTrue(feePay.usernameExists(USERNAME1));
        assertTrue(feePay.emailExists(EMAIL1));
        assertEq(feePay.getStudentCount(), 1);
        
        string memory studentId = feePay.getStudentId(student1);
        assertTrue(bytes(studentId).length > 0);
        
        (string memory id, string memory username, string memory institution, 
         string memory email, , uint256 regDate, uint256 lastLogin, FeePay.AccountStatus status, ) = 
         _getStudent(student1);
        
        assertEq(id, studentId);
        assertEq(username, USERNAME1);
        assertEq(institution, INSTITUTION);
        assertEq(email, EMAIL1);
        assertGt(regDate, 0);
        assertGt(lastLogin, 0);
        assertEq(uint8(status), uint8(FeePay.AccountStatus.ACTIVE));
    }
    
    function test_RegisterStudent_DuplicateUsername() public {
        _registerStudent(student1, USERNAME1, EMAIL1);
        
        vm.startPrank(student2);
        vm.expectRevert("Username already taken");
        feePay.registerStudent(
            USERNAME1,
            INSTITUTION,
            EMAIL2,
            PROFILE_HASH
        );
        vm.stopPrank();
    }
    
    function test_RegisterStudent_DuplicateEmail() public {
        _registerStudent(student1, USERNAME1, EMAIL1);
        
        vm.startPrank(student2);
        vm.expectRevert("Email already used");
        feePay.registerStudent(
            USERNAME2,
            INSTITUTION,
            EMAIL1,
            PROFILE_HASH
        );
        vm.stopPrank();
    }
    
    function test_RegisterStudent_InvalidUsername() public {
        vm.startPrank(student1);
        
        vm.expectRevert("Invalid username format");
        feePay.registerStudent("ab", INSTITUTION, EMAIL1, PROFILE_HASH);
        
        vm.expectRevert("Invalid username format");
        feePay.registerStudent("john@doe", INSTITUTION, EMAIL1, PROFILE_HASH);
        
        vm.stopPrank();
    }
    
    function test_RegisterStudent_InvalidEmail() public {
        vm.startPrank(student1);
        
        vm.expectRevert("Invalid email format");
        feePay.registerStudent(USERNAME1, INSTITUTION, "invalid-email", PROFILE_HASH);
        
        vm.expectRevert("Invalid email format");
        feePay.registerStudent(USERNAME1, INSTITUTION, "noatsign.com", PROFILE_HASH);
        
        vm.stopPrank();
    }
    
    function test_RegisterStudent_AlreadyRegistered() public {
        _registerStudent(student1, USERNAME1, EMAIL1);
        
        vm.startPrank(student1);
        vm.expectRevert("Already registered");
        feePay.registerStudent("new_username", INSTITUTION, "new@example.com", PROFILE_HASH);
        vm.stopPrank();
    }
    
    // ============================================
    // LOGIN TESTS
    // ============================================
    
    function test_Login() public {
        _registerStudent(student1, USERNAME1, EMAIL1);
        
        (,,,,, , uint256 initialLastLogin, ,) = _getStudent(student1);
        
        vm.warp(block.timestamp + 100);
        
        vm.startPrank(student1);
        feePay.login();
        vm.stopPrank();
        
        (,,,,, , uint256 newLastLogin, ,) = _getStudent(student1);
        assertGt(newLastLogin, initialLastLogin);
    }
    
    function test_Login_NotRegistered() public {
        vm.startPrank(randomUser);
        vm.expectRevert("Student not registered");
        feePay.login();
        vm.stopPrank();
    }
    
    // ============================================
    // PROFILE UPDATE TESTS
    // ============================================
    
    function test_UpdateProfile_Email() public {
        _registerStudent(student1, USERNAME1, EMAIL1);
        
        string memory newEmail = "newemail@example.com";
        vm.startPrank(student1);
        feePay.updateProfile(newEmail, "");
        vm.stopPrank();
        
        assertTrue(feePay.emailExists(newEmail));
        assertFalse(feePay.emailExists(EMAIL1));
    }
    
    function test_UpdateProfile_ProfileHash() public {
        _registerStudent(student1, USERNAME1, EMAIL1);
        
        string memory newHash = "ipfs://QmNewHash";
        vm.startPrank(student1);
        feePay.updateProfile("", newHash);
        vm.stopPrank();
        
        (,,,,, , , , string memory profileHash) = _getStudent(student1);
        assertEq(profileHash, newHash);
    }
    
    function test_UpdateProfile_NotRegistered() public {
        vm.startPrank(randomUser);
        vm.expectRevert("Student not registered");
        feePay.updateProfile("new@example.com", "");
        vm.stopPrank();
    }
    
    function test_UpdateProfile_InvalidEmail() public {
        _registerStudent(student1, USERNAME1, EMAIL1);
        
        vm.startPrank(student1);
        vm.expectRevert("Invalid email format");
        feePay.updateProfile("invalid", "");
        vm.stopPrank();
    }
    
    // ============================================
    // STUDENT QUERY TESTS
    // ============================================
    
    function test_GetStudentByWallet() public {
        _registerStudent(student1, USERNAME1, EMAIL1);
        
        (string memory id, string memory username, string memory institution, 
         string memory email, uint256 regDate, uint256 lastLogin, FeePay.AccountStatus status) = 
         feePay.getStudentByWallet(student1);
        
        assertEq(username, USERNAME1);
        assertEq(institution, INSTITUTION);
        assertEq(email, EMAIL1);
        assertGt(regDate, 0);
        assertGt(lastLogin, 0);
        assertEq(uint8(status), uint8(FeePay.AccountStatus.ACTIVE));
    }
    
    function test_GetStudentByWallet_NotRegistered() public {
        vm.expectRevert("Not registered");
        feePay.getStudentByWallet(randomUser);
    }
    
    function test_GetStudentById() public {
        _registerStudent(student1, USERNAME1, EMAIL1);
        string memory studentId = feePay.getStudentId(student1);
        
        (address wallet, string memory username, string memory institution, 
         string memory email, uint256 regDate, uint256 lastLogin, FeePay.AccountStatus status) = 
         feePay.getStudentById(studentId);
        
        assertEq(wallet, student1);
        assertEq(username, USERNAME1);
        assertEq(institution, INSTITUTION);
        assertEq(email, EMAIL1);
        assertGt(regDate, 0);
        assertGt(lastLogin, 0);
        assertEq(uint8(status), uint8(FeePay.AccountStatus.ACTIVE));
    }
    
    function test_GetStudentById_NotFound() public {
        vm.expectRevert("Student not found");
        feePay.getStudentById("STU20240001");
    }
    
    function test_GetAllStudents() public {
        _registerStudent(student1, USERNAME1, EMAIL1);
        _registerStudent(student2, USERNAME2, EMAIL2);
        
        address[] memory students = feePay.getAllStudents();
        assertEq(students.length, 2);
        assertEq(students[0], student1);
        assertEq(students[1], student2);
    }
    
    function test_GetStudentCount() public {
        assertEq(feePay.getStudentCount(), 0);
        _registerStudent(student1, USERNAME1, EMAIL1);
        assertEq(feePay.getStudentCount(), 1);
        _registerStudent(student2, USERNAME2, EMAIL2);
        assertEq(feePay.getStudentCount(), 2);
    }
    
    function test_IsRegistered() public {
        assertFalse(feePay.isRegistered(student1));
        _registerStudent(student1, USERNAME1, EMAIL1);
        assertTrue(feePay.isRegistered(student1));
    }
    
    function test_GetStudentId() public {
        _registerStudent(student1, USERNAME1, EMAIL1);
        string memory id = feePay.getStudentId(student1);
        assertTrue(bytes(id).length > 0);
        
        vm.expectRevert("Not registered");
        feePay.getStudentId(randomUser);
    }
    
    // ============================================
    // FEE MANAGEMENT TESTS
    // ============================================
    
    function test_UpdateFeeSchedule() public {
        vm.startPrank(admin);
        feePay.updateFeeSchedule(
            FeePay.FeeType.TUITION,
            0.1 ether,
            "Updated tuition fee"
        );
        vm.stopPrank();
        
        assertEq(feePay.getFeeAmount(FeePay.FeeType.TUITION), 0.1 ether);
        
        FeePay.FeeSchedule memory schedule = _getFeeSchedule(FeePay.FeeType.TUITION);
        assertEq(schedule.description, "Updated tuition fee");
    }
    
    function test_UpdateFeeSchedule_OnlyAdmin() public {
        vm.startPrank(randomUser);
        vm.expectRevert("Not admin");
        feePay.updateFeeSchedule(
            FeePay.FeeType.TUITION,
            0.1 ether,
            "Updated tuition fee"
        );
        vm.stopPrank();
    }
    
    function test_UpdateFeeSchedule_InvalidAmount() public {
        vm.startPrank(admin);
        
        vm.expectRevert("Fee must be between MIN and MAX");
        feePay.updateFeeSchedule(
            FeePay.FeeType.TUITION,
            0.0005 ether,
            "Too low"
        );
        
        vm.expectRevert("Fee must be between MIN and MAX");
        feePay.updateFeeSchedule(
            FeePay.FeeType.TUITION,
            11 ether,
            "Too high"
        );
        
        vm.stopPrank();
    }
    
    function test_ToggleFeeType() public {
        vm.startPrank(admin);
        feePay.toggleFeeType(FeePay.FeeType.TUITION, false);
        vm.stopPrank();
        
        FeePay.FeeSchedule memory schedule = _getFeeSchedule(FeePay.FeeType.TUITION);
        assertFalse(schedule.isActive);
        
        vm.startPrank(student1);
        vm.expectRevert("Fee type not active");
        feePay.getFeeAmount(FeePay.FeeType.TUITION);
        vm.stopPrank();
    }
    
    function test_UpdateFeeRecipient() public {
        address newRecipient = address(0x9);
        vm.startPrank(admin);
        feePay.updateFeeRecipient(FeePay.FeeType.TUITION, newRecipient);
        vm.stopPrank();
        
        assertEq(feePay.feeRecipients(FeePay.FeeType.TUITION), newRecipient);
    }
    
    function test_GetFeeSchedules() public {
        FeePay.FeeSchedule[] memory schedules = feePay.getFeeSchedules();
        assertEq(schedules.length, 7);
        assertTrue(schedules[0].isActive);
        assertGt(schedules[0].amount, 0);
    }
    
    // ============================================
    // PAYMENT TESTS
    // ============================================
    
    function test_PayFee() public {
        _registerStudent(student1, USERNAME1, EMAIL1);
        
        uint256 amount = feePay.getFeeAmount(FeePay.FeeType.TUITION);
        uint256 balanceBefore = address(feePay).balance;
        
        vm.startPrank(student1);
        feePay.payFee{value: amount}(
            FeePay.FeeType.TUITION,
            FeePay.Semester.FIRST,
            ACADEMIC_SESSION,
            "0x1234567890abcdef",
            "Test payment"
        );
        vm.stopPrank();
        
        assertEq(address(feePay).balance, balanceBefore + amount);
        assertEq(feePay.collectedFees(FeePay.FeeType.TUITION), amount);
        assertEq(feePay.totalCollected(), amount);
        
        FeePay.Payment memory payment = feePay.getPayment(0);
        assertEq(payment.payer, student1);
        assertEq(payment.studentId, feePay.getStudentId(student1));
        assertEq(payment.amount, amount);
        assertEq(uint8(payment.status), uint8(FeePay.PaymentStatus.PENDING));
        
        assertTrue(feePay.getStudentFeeStatus(FeePay.FeeType.TUITION));
    }
    
    function test_PayFee_NotRegistered() public {
        vm.startPrank(randomUser);
        vm.expectRevert("Student not registered");
        feePay.payFee{value: 0.05 ether}(
            FeePay.FeeType.TUITION,
            FeePay.Semester.FIRST,
            ACADEMIC_SESSION,
            "0x123",
            "Test"
        );
        vm.stopPrank();
    }
    
    function test_PayFee_InsufficientAmount() public {
        _registerStudent(student1, USERNAME1, EMAIL1);
        
        uint256 amount = feePay.getFeeAmount(FeePay.FeeType.TUITION);
        
        vm.startPrank(student1);
        vm.expectRevert("Insufficient payment");
        feePay.payFee{value: amount - 0.001 ether}(
            FeePay.FeeType.TUITION,
            FeePay.Semester.FIRST,
            ACADEMIC_SESSION,
            "0x123",
            "Test"
        );
        vm.stopPrank();
    }
    
    function test_PayFee_OverpaymentTooLarge() public {
        _registerStudent(student1, USERNAME1, EMAIL1);
        
        uint256 amount = feePay.getFeeAmount(FeePay.FeeType.TUITION);
        
        vm.startPrank(student1);
        vm.expectRevert("Overpayment too large");
        feePay.payFee{value: amount + 0.02 ether}(
            FeePay.FeeType.TUITION,
            FeePay.Semester.FIRST,
            ACADEMIC_SESSION,
            "0x123",
            "Test"
        );
        vm.stopPrank();
    }
    
    function test_PayFee_AlreadyPaid() public {
        _registerStudent(student1, USERNAME1, EMAIL1);
        _payFee(student1, FeePay.FeeType.TUITION);
        
        uint256 amount = feePay.getFeeAmount(FeePay.FeeType.TUITION);
        
        vm.startPrank(student1);
        vm.expectRevert("Fee already paid");
        feePay.payFee{value: amount}(
            FeePay.FeeType.TUITION,
            FeePay.Semester.FIRST,
            ACADEMIC_SESSION,
            "0x123",
            "Test"
        );
        vm.stopPrank();
    }
    
    function test_PayFee_MultipleFeeTypes() public {
        _registerStudent(student1, USERNAME1, EMAIL1);
        
        _payFee(student1, FeePay.FeeType.TUITION);
        assertTrue(feePay.getStudentFeeStatus(FeePay.FeeType.TUITION));
        assertFalse(feePay.getStudentFeeStatus(FeePay.FeeType.HOSTEL));
        
        _payFee(student1, FeePay.FeeType.HOSTEL);
        assertTrue(feePay.getStudentFeeStatus(FeePay.FeeType.TUITION));
        assertTrue(feePay.getStudentFeeStatus(FeePay.FeeType.HOSTEL));
        
        assertEq(feePay.getTotalPaymentsCount(), 2);
    }
    
    // ============================================
    // PAYMENT CONFIRMATION TESTS
    // ============================================
    
    function test_ConfirmPayment() public {
        _registerStudent(student1, USERNAME1, EMAIL1);
        _payFee(student1, FeePay.FeeType.TUITION);
        
        vm.startPrank(admin);
        feePay.confirmPayment(0);
        vm.stopPrank();
        
        FeePay.Payment memory payment = feePay.getPayment(0);
        assertEq(uint8(payment.status), uint8(FeePay.PaymentStatus.CONFIRMED));
        assertEq(payment.confirmations, 12);
    }
    
    function test_ConfirmPayment_OnlyAdmin() public {
        _registerStudent(student1, USERNAME1, EMAIL1);
        _payFee(student1, FeePay.FeeType.TUITION);
        
        vm.startPrank(randomUser);
        vm.expectRevert("Not admin");
        feePay.confirmPayment(0);
        vm.stopPrank();
    }
    
    function test_ConfirmPayment_AlreadyConfirmed() public {
        _registerStudent(student1, USERNAME1, EMAIL1);
        _payFee(student1, FeePay.FeeType.TUITION);
        
        vm.startPrank(admin);
        feePay.confirmPayment(0);
        vm.expectRevert("Not pending");
        feePay.confirmPayment(0);
        vm.stopPrank();
    }
    
    // ============================================
    // REFUND TESTS
    // ============================================
    
    function test_RefundPayment() public {
        _registerStudent(student1, USERNAME1, EMAIL1);
        uint256 amount = feePay.getFeeAmount(FeePay.FeeType.TUITION);
        _payFee(student1, FeePay.FeeType.TUITION);
        
        uint256 studentBalanceBefore = student1.balance;
        
        vm.startPrank(admin);
        feePay.refundPayment(0);
        vm.stopPrank();
        
        FeePay.Payment memory payment = feePay.getPayment(0);
        assertEq(uint8(payment.status), uint8(FeePay.PaymentStatus.REFUNDED));
        assertEq(student1.balance, studentBalanceBefore + amount);
        assertEq(feePay.collectedFees(FeePay.FeeType.TUITION), 0);
        assertEq(feePay.totalCollected(), 0);
    }
    
    function test_RefundPayment_OnlyAdmin() public {
        _registerStudent(student1, USERNAME1, EMAIL1);
        _payFee(student1, FeePay.FeeType.TUITION);
        
        vm.startPrank(randomUser);
        vm.expectRevert("Not admin");
        feePay.refundPayment(0);
        vm.stopPrank();
    }
    
    function test_RefundPayment_AlreadyRefunded() public {
        _registerStudent(student1, USERNAME1, EMAIL1);
        _payFee(student1, FeePay.FeeType.TUITION);
        
        vm.startPrank(admin);
        feePay.refundPayment(0);
        vm.expectRevert("Already refunded");
        feePay.refundPayment(0);
        vm.stopPrank();
    }
    
    // ============================================
    // PAYMENT QUERY TESTS
    // ============================================
    
    function test_GetMyPayments() public {
        _registerStudent(student1, USERNAME1, EMAIL1);
        _payFee(student1, FeePay.FeeType.TUITION);
        _payFee(student1, FeePay.FeeType.HOSTEL);
        
        vm.startPrank(student1);
        FeePay.Payment[] memory myPayments = feePay.getMyPayments();
        vm.stopPrank();
        
        assertEq(myPayments.length, 2);
        assertEq(myPayments[0].payer, student1);
        assertEq(myPayments[1].payer, student1);
    }
    
    function test_GetMyPayments_NotRegistered() public {
        vm.startPrank(randomUser);
        vm.expectRevert("Student not registered");
        feePay.getMyPayments();
        vm.stopPrank();
    }
    
    function test_GetPaymentsByStudent() public {
        _registerStudent(student1, USERNAME1, EMAIL1);
        string memory studentId = feePay.getStudentId(student1);
        _payFee(student1, FeePay.FeeType.TUITION);
        
        FeePay.Payment[] memory payments = feePay.getPaymentsByStudent(studentId);
        assertEq(payments.length, 1);
        assertEq(payments[0].studentId, studentId);
    }
    
    function test_GetRecentPayments() public {
        _registerStudent(student1, USERNAME1, EMAIL1);
        _registerStudent(student2, USERNAME2, EMAIL2);
        _payFee(student1, FeePay.FeeType.TUITION);
        _payFee(student2, FeePay.FeeType.TUITION);
        
        FeePay.Payment[] memory recent = feePay.getRecentPayments(5);
        assertEq(recent.length, 2);
    }
    
    function test_GetPendingCount() public {
        _registerStudent(student1, USERNAME1, EMAIL1);
        _registerStudent(student2, USERNAME2, EMAIL2);
        _payFee(student1, FeePay.FeeType.TUITION);
        _payFee(student2, FeePay.FeeType.TUITION);
        
        assertEq(feePay.getPendingCount(), 2);
        
        vm.startPrank(admin);
        feePay.confirmPayment(0);
        vm.stopPrank();
        
        assertEq(feePay.getPendingCount(), 1);
    }
    
    function test_GetContractBalance() public {
        assertEq(feePay.getContractBalance(), 0);
        _registerStudent(student1, USERNAME1, EMAIL1);
        _payFee(student1, FeePay.FeeType.TUITION);
        assertEq(feePay.getContractBalance(), 0.05 ether);
    }
    
    function test_GetStudentFeeStatus() public {
        _registerStudent(student1, USERNAME1, EMAIL1);
        
        bool initialStatus = feePay.getStudentFeeStatus(FeePay.FeeType.TUITION);
        assertFalse(initialStatus);
        
        _payFee(student1, FeePay.FeeType.TUITION);
        
        bool updatedStatus = feePay.getStudentFeeStatus(FeePay.FeeType.TUITION);
        assertTrue(updatedStatus);
    }
    
    // ============================================
    // TREASURY TESTS
    // ============================================
    
    function test_WithdrawFees() public {
        _registerStudent(student1, USERNAME1, EMAIL1);
        _payFee(student1, FeePay.FeeType.TUITION);
        
        vm.startPrank(admin);
        feePay.confirmPayment(0);
        vm.stopPrank();
        
        uint256 balanceBefore = owner.balance;
        
        vm.startPrank(treasurer);
        feePay.withdrawFees(FeePay.FeeType.TUITION);
        vm.stopPrank();
        
        assertEq(feePay.collectedFees(FeePay.FeeType.TUITION), 0);
        assertGt(owner.balance, balanceBefore);
    }
    
    function test_WithdrawFees_OnlyTreasurer() public {
        _registerStudent(student1, USERNAME1, EMAIL1);
        _payFee(student1, FeePay.FeeType.TUITION);
        
        vm.startPrank(admin);
        feePay.confirmPayment(0);
        vm.stopPrank();
        
        vm.startPrank(randomUser);
        vm.expectRevert("Not treasurer");
        feePay.withdrawFees(FeePay.FeeType.TUITION);
        vm.stopPrank();
    }
    
    function test_WithdrawFees_DailyLimit() public {
        _registerStudent(student1, USERNAME1, EMAIL1);
        _registerStudent(student2, USERNAME2, EMAIL2);
        _payFee(student1, FeePay.FeeType.TUITION);
        _payFee(student2, FeePay.FeeType.HOSTEL);
        
        vm.startPrank(admin);
        feePay.confirmPayment(0);
        feePay.confirmPayment(1);
        vm.stopPrank();
        
        vm.startPrank(treasurer);
        feePay.withdrawFees(FeePay.FeeType.TUITION);
        
        vm.expectRevert("Daily withdrawal limit exceeded");
        feePay.withdrawFees(FeePay.FeeType.HOSTEL);
        vm.stopPrank();
    }
    
    function test_EmergencyWithdrawUntrackedFunds() public {
        vm.deal(address(feePay), 1 ether);
        
        uint256 balanceBefore = owner.balance;
        vm.startPrank(owner);
        feePay.emergencyWithdrawUntrackedFunds();
        vm.stopPrank();
        
        assertGt(owner.balance, balanceBefore);
        assertEq(feePay.getContractBalance(), 0);
    }
    
    function test_EmergencyWithdrawUntrackedFunds_OnlyOwner() public {
        vm.deal(address(feePay), 1 ether);
        
        vm.startPrank(randomUser);
        vm.expectRevert("Not owner");
        feePay.emergencyWithdrawUntrackedFunds();
        vm.stopPrank();
    }
    
    // ============================================
    // ADMIN TESTS
    // ============================================
    
    function test_AddAdmin() public {
        address newAdmin = address(0x9);
        vm.startPrank(owner);
        feePay.addAdmin(newAdmin);
        vm.stopPrank();
        
        assertTrue(feePay.admins(newAdmin));
    }
    
    function test_AddAdmin_OnlyOwner() public {
        address newAdmin = address(0x9);
        vm.startPrank(randomUser);
        vm.expectRevert("Not owner");
        feePay.addAdmin(newAdmin);
        vm.stopPrank();
    }
    
    function test_RemoveAdmin() public {
        vm.startPrank(owner);
        feePay.removeAdmin(admin);
        vm.stopPrank();
        
        assertFalse(feePay.admins(admin));
    }
    
    function test_AddTreasurer() public {
        address newTreasurer = address(0x9);
        vm.startPrank(admin);
        feePay.addTreasurer(newTreasurer);
        vm.stopPrank();
        
        assertTrue(feePay.treasurers(newTreasurer));
    }
    
    function test_RemoveTreasurer() public {
        vm.startPrank(admin);
        feePay.removeTreasurer(treasurer);
        vm.stopPrank();
        
        assertFalse(feePay.treasurers(treasurer));
    }
    
    function test_SuspendStudent() public {
        _registerStudent(student1, USERNAME1, EMAIL1);
        
        vm.startPrank(admin);
        feePay.suspendStudent(student1);
        vm.stopPrank();
        
        (,,,,, , , FeePay.AccountStatus status, ) = _getStudent(student1);
        assertEq(uint8(status), uint8(FeePay.AccountStatus.SUSPENDED));
    }
    
    function test_SuspendStudent_OnlyAdmin() public {
        _registerStudent(student1, USERNAME1, EMAIL1);
        
        vm.startPrank(randomUser);
        vm.expectRevert("Not admin");
        feePay.suspendStudent(student1);
        vm.stopPrank();
    }
    
    function test_ReactivateStudent() public {
        _registerStudent(student1, USERNAME1, EMAIL1);
        
        vm.startPrank(admin);
        feePay.suspendStudent(student1);
        feePay.reactivateStudent(student1);
        vm.stopPrank();
        
        (,,,,, , , FeePay.AccountStatus status, ) = _getStudent(student1);
        assertEq(uint8(status), uint8(FeePay.AccountStatus.ACTIVE));
    }
    
    // ============================================
    // PAUSE TESTS
    // ============================================
    
    function test_PauseContract() public {
        vm.startPrank(admin);
        feePay.pause();
        assertTrue(feePay.paused());
        vm.stopPrank();
        
        vm.startPrank(student1);
        vm.expectRevert("Contract paused");
        feePay.registerStudent(USERNAME1, INSTITUTION, EMAIL1, PROFILE_HASH);
        vm.stopPrank();
    }
    
    function test_UnpauseContract() public {
        vm.startPrank(admin);
        feePay.pause();
        feePay.unpause();
        assertFalse(feePay.paused());
        vm.stopPrank();
    }
    
    function test_Pause_OnlyAdmin() public {
        vm.startPrank(randomUser);
        vm.expectRevert("Not admin");
        feePay.pause();
        vm.stopPrank();
    }
    
    // ============================================
    // SETTER TESTS
    // ============================================
    
    function test_SetRequiredConfirmations() public {
        vm.startPrank(admin);
        feePay.setRequiredConfirmations(20);
        assertEq(feePay.requiredConfirmations(), 20);
        vm.stopPrank();
    }
    
    function test_SetDailyWithdrawalLimit() public {
        vm.startPrank(admin);
        feePay.setDailyWithdrawalLimit(10 ether);
        assertEq(feePay.dailyWithdrawalLimit(), 10 ether);
        vm.stopPrank();
    }
    
    // ============================================
    // RECEIVE FUNCTION TESTS
    // ============================================
    
    function test_ReceiveEth() public {
        uint256 amount = 1 ether;
        uint256 balanceBefore = address(feePay).balance;
        
        vm.deal(randomUser, amount);
        vm.startPrank(randomUser);
        (bool success, ) = address(feePay).call{value: amount}("");
        vm.stopPrank();
        
        assertTrue(success);
        assertEq(address(feePay).balance, balanceBefore + amount);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title FeePay - Self-Registration School Fees Payment System
 * @dev Students register themselves with wallet authentication
 */
contract FeePay {
    // ============================================
    // ENUMS & STRUCTS
    // ============================================
    
    enum PaymentStatus { PENDING, CONFIRMED, FAILED, REFUNDED }
    enum FeeType { TUITION, HOSTEL, LIBRARY, LAB, SPORTS, EXAMINATION, OTHER }
    enum Semester { NONE, FIRST, SECOND, SUMMER }
    enum AccountStatus { ACTIVE, SUSPENDED, GRADUATED }
    
    struct Student {
        string studentId;
        string username;
        string institution;
        string email;
        address walletAddress;
        uint256 registrationDate;
        uint256 lastLogin;
        AccountStatus status;
        mapping(FeeType => bool) feesPaid;
        mapping(uint256 => uint256[]) paymentIds;
        string profileHash;
    }
    
    struct Payment {
        uint256 id;
        address payer;
        string studentId;
        FeeType feeType;
        Semester semester;
        string academicSession;
        uint256 amount;
        uint256 timestamp;
        uint256 blockNumber;
        PaymentStatus status;
        uint256 confirmations;
        string transactionHash;
        string notes;
    }
    
    struct FeeSchedule {
        FeeType feeType;
        uint256 amount;
        bool isActive;
        string description;
    }
    
    // ============================================
    // STATE VARIABLES
    // ============================================
    
    // Student Management
    mapping(address => Student) public students;
    mapping(string => address) public studentIdToAddress;
    mapping(string => bool) public usernameExists;
    mapping(string => bool) public emailExists;
    address[] public studentAddresses;
    uint256 public studentCount;
    
    // Fee Management
    mapping(FeeType => FeeSchedule) public feeSchedules;
    FeeType[] public feeTypesList;
    mapping(FeeType => address) public feeRecipients;
    mapping(FeeType => uint256) public collectedFees;
    uint256 public totalCollected;
    uint256 public constant MAX_FEE = 10 ether;
    uint256 public constant MIN_FEE = 0.001 ether;
    uint256 public constant MAX_OVERPAYMENT = 0.01 ether;
    
    // Payment Tracking
    Payment[] public payments;
    mapping(address => uint256[]) public paymentsByPayer;
    mapping(string => uint256[]) public paymentsByStudent;
    mapping(FeeType => uint256[]) public paymentsByFeeType;
    mapping(address => mapping(FeeType => uint256)) public paymentCountByStudentFee;
    uint8 public requiredConfirmations = 12;
    
    // Admin/System
    address public owner;
    address public treasurer;
    mapping(address => bool) public admins;
    mapping(address => bool) public treasurers;
    bool public paused;
    uint256 public dailyWithdrawalLimit = 5 ether;
    mapping(address => uint256) public dailyWithdrawalAmount;
    mapping(address => uint256) public lastWithdrawalDay;
    
    // ============================================
    // EVENTS
    // ============================================
    
    event StudentRegistered(
        address indexed wallet, 
        string indexed studentId, 
        string username, 
        string institution,
        uint256 timestamp
    );
    event StudentUpdated(address indexed wallet, string field, string value);
    event StudentLoggedIn(address indexed wallet, uint256 timestamp);
    event StudentSuspended(address indexed wallet, address indexed admin);
    event StudentReactivated(address indexed wallet, address indexed admin);
    event FeeScheduleUpdated(FeeType indexed feeType, uint256 amount);
    event FeeTypeToggled(FeeType indexed feeType, bool isActive);
    event FeeRecipientUpdated(FeeType indexed feeType, address indexed oldRecipient, address indexed newRecipient);
    event PaymentSubmitted(uint256 indexed paymentId, address indexed payer, string studentId, FeeType feeType, uint256 amount);
    event PaymentConfirmed(uint256 indexed paymentId, uint256 confirmations);
    event PaymentRefunded(uint256 indexed paymentId, address indexed payer, uint256 amount);
    event FundsWithdrawn(FeeType indexed feeType, address indexed recipient, uint256 amount);
    event EmergencyWithdrawal(address indexed recipient, uint256 amount);
    event AdminAdded(address indexed admin);
    event AdminRemoved(address indexed admin);
    event TreasurerAdded(address indexed treasurer);
    event TreasurerRemoved(address indexed treasurer);
    event ContractPaused(address indexed admin);
    event ContractUnpaused(address indexed admin);
    event WithdrawalLimitUpdated(uint256 oldLimit, uint256 newLimit);
    event ConfirmationsUpdated(uint8 oldConfirmations, uint8 newConfirmations);
    
    // ============================================
    // MODIFIERS
    // ============================================
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    modifier onlyAdmin() {
        require(msg.sender == owner || admins[msg.sender], "Not admin");
        _;
    }
    
    modifier onlyTreasurer() {
        require(msg.sender == owner || treasurers[msg.sender], "Not treasurer");
        _;
    }
    
    modifier whenNotPaused() {
        require(!paused, "Contract paused");
        _;
    }
    
    modifier studentExists() {
        require(students[msg.sender].registrationDate > 0, "Student not registered");
        _;
    }
    
    modifier studentActive() {
        require(students[msg.sender].status == AccountStatus.ACTIVE, "Account not active");
        _;
    }
    
    modifier validStudent(string memory studentId) {
        require(studentIdToAddress[studentId] != address(0), "Student not found");
        require(students[studentIdToAddress[studentId]].status == AccountStatus.ACTIVE, "Student not active");
        _;
    }
    
    modifier validFeeType(FeeType feeType) {
        require(feeSchedules[feeType].isActive, "Fee type not active");
        _;
    }
    
    // ============================================
    // CONSTRUCTOR
    // ============================================
    
    constructor() {
        owner = msg.sender;
        treasurer = msg.sender;
        admins[msg.sender] = true;
        treasurers[msg.sender] = true;
        _initializeFeeSchedules();
    }
    
    function _initializeFeeSchedules() internal {
        feeSchedules[FeeType.TUITION] = FeeSchedule({
            feeType: FeeType.TUITION,
            amount: 0.05 ether,
            isActive: true,
            description: "Tuition Fee"
        });
        feeTypesList.push(FeeType.TUITION);
        feeRecipients[FeeType.TUITION] = owner;
        
        feeSchedules[FeeType.HOSTEL] = FeeSchedule({
            feeType: FeeType.HOSTEL,
            amount: 0.025 ether,
            isActive: true,
            description: "Hostel Accommodation Fee"
        });
        feeTypesList.push(FeeType.HOSTEL);
        feeRecipients[FeeType.HOSTEL] = owner;
        
        feeSchedules[FeeType.LIBRARY] = FeeSchedule({
            feeType: FeeType.LIBRARY,
            amount: 0.01 ether,
            isActive: true,
            description: "Library Services Fee"
        });
        feeTypesList.push(FeeType.LIBRARY);
        feeRecipients[FeeType.LIBRARY] = owner;
        
        feeSchedules[FeeType.LAB] = FeeSchedule({
            feeType: FeeType.LAB,
            amount: 0.015 ether,
            isActive: true,
            description: "Computer Laboratory Fee"
        });
        feeTypesList.push(FeeType.LAB);
        feeRecipients[FeeType.LAB] = owner;
        
        feeSchedules[FeeType.SPORTS] = FeeSchedule({
            feeType: FeeType.SPORTS,
            amount: 0.008 ether,
            isActive: true,
            description: "Sports Activities Fee"
        });
        feeTypesList.push(FeeType.SPORTS);
        feeRecipients[FeeType.SPORTS] = owner;
        
        feeSchedules[FeeType.EXAMINATION] = FeeSchedule({
            feeType: FeeType.EXAMINATION,
            amount: 0.012 ether,
            isActive: true,
            description: "Examination Fee"
        });
        feeTypesList.push(FeeType.EXAMINATION);
        feeRecipients[FeeType.EXAMINATION] = owner;
        
        feeSchedules[FeeType.OTHER] = FeeSchedule({
            feeType: FeeType.OTHER,
            amount: 0.01 ether,
            isActive: true,
            description: "Other Fees"
        });
        feeTypesList.push(FeeType.OTHER);
        feeRecipients[FeeType.OTHER] = owner;
    }
    
    // ============================================
    // HELPER FUNCTIONS
    // ============================================
    
    function _isValidEmail(string memory email) internal pure returns (bool) {
        bytes memory b = bytes(email);
        bool hasAt = false;
        bool hasDot = false;
        for (uint i = 0; i < b.length; i++) {
            if (b[i] == '@') hasAt = true;
            if (b[i] == '.' && hasAt) hasDot = true;
        }
        return hasAt && hasDot && b.length >= 5 && b.length <= 100;
    }
    
    function _isValidUsername(string memory username) internal pure returns (bool) {
        bytes memory b = bytes(username);
        if (b.length < 3 || b.length > 30) return false;
        for (uint i = 0; i < b.length; i++) {
            bytes1 char = b[i];
            if (!((char >= 'a' && char <= 'z') || 
                  (char >= 'A' && char <= 'Z') || 
                  (char >= '0' && char <= '9') || 
                  char == '_' || char == '.')) {
                return false;
            }
        }
        return true;
    }
    
    function _uintToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        uint256 index = digits;
        while (value != 0) {
            index--;
            buffer[index] = bytes1(uint8(48 + value % 10));
            value /= 10;
        }
        return string(buffer);
    }
    
    function _stringContains(string memory str, string memory substr) internal pure returns (bool) {
        bytes memory strBytes = bytes(str);
        bytes memory subBytes = bytes(substr);
        if (subBytes.length == 0) return true;
        if (subBytes.length > strBytes.length) return false;
        for (uint i = 0; i <= strBytes.length - subBytes.length; i++) {
            bool found = true;
            for (uint j = 0; j < subBytes.length; j++) {
                if (strBytes[i + j] != subBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) return true;
        }
        return false;
    }
    
    // ============================================
    // STUDENT SELF-REGISTRATION
    // ============================================
    
    function registerStudent(
        string memory username,
        string memory institution,
        string memory email,
        string memory profileHash
    ) 
        external 
        whenNotPaused 
    {
        require(students[msg.sender].registrationDate == 0, "Already registered");
        require(bytes(username).length > 0, "Username required");
        require(_isValidUsername(username), "Invalid username format");
        require(!usernameExists[username], "Username already taken");
        require(bytes(institution).length > 0 && bytes(institution).length <= 100, "Invalid institution name");
        
        if (bytes(email).length > 0) {
            require(_isValidEmail(email), "Invalid email format");
            require(!emailExists[email], "Email already used");
        }
        
        string memory studentId = _generateStudentId();
        
        Student storage student = students[msg.sender];
        student.studentId = studentId;
        student.username = username;
        student.institution = institution;
        student.email = email;
        student.walletAddress = msg.sender;
        student.registrationDate = block.timestamp;
        student.lastLogin = block.timestamp;
        student.status = AccountStatus.ACTIVE;
        student.profileHash = profileHash;
        
        studentIdToAddress[studentId] = msg.sender;
        usernameExists[username] = true;
        if (bytes(email).length > 0) {
            emailExists[email] = true;
        }
        studentAddresses.push(msg.sender);
        studentCount++;
        
        emit StudentRegistered(msg.sender, studentId, username, institution, block.timestamp);
    }
    
    function _generateStudentId() internal view returns (string memory) {
        uint256 year = block.timestamp / 365 days + 1970;
        uint256 count = studentCount + 1;
        string memory yearStr = _uintToString(year);
        string memory countStr = _uintToString(count);
        while (bytes(countStr).length < 4) {
            countStr = string(abi.encodePacked("0", countStr));
        }
        string memory addressSuffix = string(abi.encodePacked(
            bytes1(uint8(uint160(msg.sender) % 100))
        ));
        return string(abi.encodePacked("STU", yearStr, countStr, addressSuffix));
    }
    
    function login() external studentExists {
        students[msg.sender].lastLogin = block.timestamp;
        emit StudentLoggedIn(msg.sender, block.timestamp);
    }
    
    function updateProfile(
        string memory email,
        string memory profileHash
    ) 
        external 
        studentExists 
        studentActive 
        whenNotPaused 
    {
        if (bytes(email).length > 0) {
            require(_isValidEmail(email), "Invalid email format");
            if (bytes(students[msg.sender].email).length > 0) {
                emailExists[students[msg.sender].email] = false;
            }
            require(!emailExists[email] || keccak256(bytes(email)) == keccak256(bytes(students[msg.sender].email)), "Email already used");
            students[msg.sender].email = email;
            emailExists[email] = true;
        }
        
        if (bytes(profileHash).length > 0) {
            students[msg.sender].profileHash = profileHash;
        }
        
        emit StudentUpdated(msg.sender, "profile", "Updated");
    }
    
    function isRegistered(address wallet) external view returns (bool) {
        return students[wallet].registrationDate > 0;
    }
    
    function getStudentId(address wallet) external view returns (string memory) {
        require(students[wallet].registrationDate > 0, "Not registered");
        return students[wallet].studentId;
    }
    
    function getStudentByWallet(address wallet) external view returns (
        string memory studentId,
        string memory username,
        string memory institution,
        string memory email,
        uint256 registrationDate,
        uint256 lastLogin,
        AccountStatus status
    ) {
        require(students[wallet].registrationDate > 0, "Not registered");
        Student storage student = students[wallet];
        return (
            student.studentId,
            student.username,
            student.institution,
            student.email,
            student.registrationDate,
            student.lastLogin,
            student.status
        );
    }
    
    function getStudentById(string memory studentId) external view returns (
        address wallet,
        string memory username,
        string memory institution,
        string memory email,
        uint256 registrationDate,
        uint256 lastLogin,
        AccountStatus status
    ) {
        address walletAddr = studentIdToAddress[studentId];
        require(walletAddr != address(0), "Student not found");
        Student storage student = students[walletAddr];
        return (
            walletAddr,
            student.username,
            student.institution,
            student.email,
            student.registrationDate,
            student.lastLogin,
            student.status
        );
    }
    
    function getAllStudents() external view returns (address[] memory) {
        return studentAddresses;
    }
    
    function getStudentCount() external view returns (uint256) {
        return studentCount;
    }
    
    // ============================================
    // ADMIN - STUDENT MANAGEMENT
    // ============================================
    
    function suspendStudent(address wallet) external onlyAdmin whenNotPaused {
        require(students[wallet].registrationDate > 0, "Not registered");
        require(students[wallet].status != AccountStatus.SUSPENDED, "Already suspended");
        students[wallet].status = AccountStatus.SUSPENDED;
        emit StudentSuspended(wallet, msg.sender);
    }
    
    function reactivateStudent(address wallet) external onlyAdmin whenNotPaused {
        require(students[wallet].registrationDate > 0, "Not registered");
        require(students[wallet].status == AccountStatus.SUSPENDED, "Not suspended");
        students[wallet].status = AccountStatus.ACTIVE;
        emit StudentReactivated(wallet, msg.sender);
    }
    
    // ============================================
    // FEE MANAGEMENT
    // ============================================
    
    function updateFeeSchedule(
        FeeType feeType,
        uint256 amount,
        string memory description
    ) external onlyAdmin whenNotPaused {
        require(amount >= MIN_FEE && amount <= MAX_FEE, "Fee must be between MIN and MAX");
        require(bytes(description).length > 0 && bytes(description).length <= 200, "Invalid description");
        
        feeSchedules[feeType].amount = amount;
        feeSchedules[feeType].description = description;
        feeSchedules[feeType].isActive = true;
        
        emit FeeScheduleUpdated(feeType, amount);
    }
    
    function toggleFeeType(FeeType feeType, bool isActive) external onlyAdmin {
        feeSchedules[feeType].isActive = isActive;
        emit FeeTypeToggled(feeType, isActive);
    }
    
    function updateFeeRecipient(FeeType feeType, address recipient) external onlyAdmin {
        require(recipient != address(0), "Invalid address");
        address oldRecipient = feeRecipients[feeType];
        feeRecipients[feeType] = recipient;
        emit FeeRecipientUpdated(feeType, oldRecipient, recipient);
    }
    
    function getFeeSchedules() external view returns (FeeSchedule[] memory) {
        FeeSchedule[] memory schedules = new FeeSchedule[](feeTypesList.length);
        for (uint i = 0; i < feeTypesList.length; i++) {
            schedules[i] = feeSchedules[feeTypesList[i]];
        }
        return schedules;
    }
    
    function getFeeAmount(FeeType feeType) public view returns (uint256) {
        require(feeSchedules[feeType].isActive, "Fee type not active");
        return feeSchedules[feeType].amount;
    }
    
    // ============================================
    // PAYMENT SYSTEM
    // ============================================
    
    function payFee(
        FeeType feeType,
        Semester semester,
        string memory academicSession,
        string memory transactionHash,
        string memory notes
    ) 
        external
        payable
        whenNotPaused 
    {
        require(students[msg.sender].registrationDate > 0, "Student not registered");
        require(students[msg.sender].status == AccountStatus.ACTIVE, "Account not active");
        require(feeSchedules[feeType].isActive, "Fee type not active");
        
        Student storage student = students[msg.sender];
        require(!student.feesPaid[feeType], "Fee already paid");
        require(bytes(academicSession).length > 0 && bytes(academicSession).length <= 20, "Invalid session");
        
        uint256 requiredAmount = feeSchedules[feeType].amount;
        require(msg.value >= requiredAmount, "Insufficient payment");
        require(msg.value <= requiredAmount + MAX_OVERPAYMENT, "Overpayment too large");
        require(msg.value <= MAX_FEE, "Payment exceeds max fee");
        
        _recordPayment(msg.sender, student.studentId, feeType, semester, academicSession, transactionHash, notes, msg.value);
        student.feesPaid[feeType] = true;
        collectedFees[feeType] += msg.value;
        totalCollected += msg.value;
    }
    
    function _recordPayment(
        address payer,
        string memory studentId,
        FeeType feeType,
        Semester semester,
        string memory academicSession,
        string memory transactionHash,
        string memory notes,
        uint256 amount
    ) internal {
        uint256 paymentId = payments.length;
        
        Payment memory newPayment = Payment({
            id: paymentId,
            payer: payer,
            studentId: studentId,
            feeType: feeType,
            semester: semester,
            academicSession: academicSession,
            amount: amount,
            timestamp: block.timestamp,
            blockNumber: block.number,
            status: PaymentStatus.PENDING,
            confirmations: 0,
            transactionHash: transactionHash,
            notes: notes
        });
        
        payments.push(newPayment);
        paymentsByPayer[payer].push(paymentId);
        paymentsByStudent[studentId].push(paymentId);
        paymentsByFeeType[feeType].push(paymentId);
        paymentCountByStudentFee[payer][feeType]++;
        
        emit PaymentSubmitted(paymentId, payer, studentId, feeType, amount);
        _checkAndUpdatePaymentStatus(paymentId);
    }
    
    function _checkAndUpdatePaymentStatus(uint256 paymentId) internal {
        Payment storage payment = payments[paymentId];
        uint256 currentBlock = block.number;
        uint256 elapsedBlocks = currentBlock - payment.blockNumber;
        payment.confirmations = elapsedBlocks;
        
        if (elapsedBlocks >= requiredConfirmations && payment.status == PaymentStatus.PENDING) {
            payment.status = PaymentStatus.CONFIRMED;
            emit PaymentConfirmed(paymentId, elapsedBlocks);
        }
    }
    
    function confirmPayment(uint256 paymentId) external onlyAdmin {
        require(paymentId < payments.length, "Invalid payment ID");
        Payment storage payment = payments[paymentId];
        require(payment.status == PaymentStatus.PENDING, "Not pending");
        payment.status = PaymentStatus.CONFIRMED;
        payment.confirmations = requiredConfirmations;
        emit PaymentConfirmed(paymentId, requiredConfirmations);
    }
    
    function refundPayment(uint256 paymentId) external onlyAdmin whenNotPaused {
        require(paymentId < payments.length, "Invalid payment ID");
        Payment storage payment = payments[paymentId];
        require(payment.status != PaymentStatus.REFUNDED, "Already refunded");
        
        uint256 amount = payment.amount;
        address payable payer = payable(payment.payer);
        
        payment.status = PaymentStatus.REFUNDED;
        if (amount > 0) {
            collectedFees[payment.feeType] -= amount;
            totalCollected -= amount;
        }
        
        if (amount > 0) {
            (bool success, ) = payer.call{value: amount}("");
            require(success, "Transfer failed");
        }
        
        emit PaymentRefunded(paymentId, payer, amount);
    }
    
    // ============================================
    // PAYMENT QUERIES
    // ============================================
    
    function getPayment(uint256 paymentId) external view returns (Payment memory) {
        require(paymentId < payments.length, "Invalid payment ID");
        return payments[paymentId];
    }
    
    function getMyPayments() external view returns (Payment[] memory) {
        require(students[msg.sender].registrationDate > 0, "Student not registered");
        uint256[] storage paymentIds = paymentsByPayer[msg.sender];
        Payment[] memory result = new Payment[](paymentIds.length);
        for (uint i = 0; i < paymentIds.length; i++) {
            result[i] = payments[paymentIds[i]];
        }
        return result;
    }
    
    function getPaymentsByStudent(string memory studentId) 
        external 
        view 
        validStudent(studentId)
        returns (Payment[] memory) 
    {
        uint256[] storage paymentIds = paymentsByStudent[studentId];
        Payment[] memory result = new Payment[](paymentIds.length);
        for (uint i = 0; i < paymentIds.length; i++) {
            result[i] = payments[paymentIds[i]];
        }
        return result;
    }
    
    function getRecentPayments(uint256 limit) external view returns (Payment[] memory) {
        uint256 count = payments.length;
        if (count == 0) return new Payment[](0);
        
        uint256 resultCount = count < limit ? count : limit;
        Payment[] memory result = new Payment[](resultCount);
        for (uint i = 0; i < resultCount; i++) {
            result[i] = payments[count - 1 - i];
        }
        return result;
    }
    
    function getPendingCount() external view returns (uint256) {
        uint256 count = 0;
        for (uint i = 0; i < payments.length; i++) {
            if (payments[i].status == PaymentStatus.PENDING) {
                count++;
            }
        }
        return count;
    }
    
    function getTotalPaymentsCount() external view returns (uint256) {
        return payments.length;
    }
    
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    function getStudentFeeStatus(FeeType feeType) 
        external 
        view 
        returns (bool paid) 
    {
        require(students[msg.sender].registrationDate > 0, "Student not registered");
        return students[msg.sender].feesPaid[feeType];
    }
    
    // ============================================
    // TREASURY
    // ============================================
    
    function withdrawFees(FeeType feeType) external onlyTreasurer whenNotPaused {
        uint256 amount = collectedFees[feeType];
        require(amount > 0, "No funds to withdraw");
        require(feeRecipients[feeType] != address(0), "No recipient set");
        
        uint256 today = block.timestamp / 1 days;
        if (lastWithdrawalDay[msg.sender] != today) {
            lastWithdrawalDay[msg.sender] = today;
            dailyWithdrawalAmount[msg.sender] = 0;
        }
        require(
            dailyWithdrawalAmount[msg.sender] + amount <= dailyWithdrawalLimit,
            "Daily withdrawal limit exceeded"
        );
        
        collectedFees[feeType] = 0;
        dailyWithdrawalAmount[msg.sender] += amount;
        (bool success, ) = payable(feeRecipients[feeType]).call{value: amount}("");
        require(success, "Transfer failed");
        emit FundsWithdrawn(feeType, feeRecipients[feeType], amount);
    }
    
    function emergencyWithdrawUntrackedFunds() external onlyOwner whenNotPaused {
        uint256 balance = address(this).balance;
        uint256 trackedTotal = totalCollected;
        require(balance > trackedTotal, "No untracked funds");
        uint256 untracked = balance - trackedTotal;
        require(untracked > 0, "No untracked funds to withdraw");
        
        (bool success, ) = payable(owner).call{value: untracked}("");
        require(success, "Transfer failed");
        emit EmergencyWithdrawal(owner, untracked);
    }
    
    // ============================================
    // ADMIN
    // ============================================
    
    function addAdmin(address admin) external onlyOwner {
        require(admin != address(0), "Invalid address");
        require(admin != owner, "Already owner");
        require(!admins[admin], "Already admin");
        admins[admin] = true;
        emit AdminAdded(admin);
    }
    
    function removeAdmin(address admin) external onlyOwner {
        require(admin != owner, "Cannot remove owner");
        require(admins[admin], "Not an admin");
        admins[admin] = false;
        emit AdminRemoved(admin);
    }
    
    function addTreasurer(address newTreasurer) external onlyAdmin {
        require(newTreasurer != address(0), "Invalid address");
        require(!treasurers[newTreasurer], "Already treasurer");
        treasurers[newTreasurer] = true;
        emit TreasurerAdded(newTreasurer);
    }
    
    function removeTreasurer(address treasurerToRemove) external onlyAdmin {
        require(treasurers[treasurerToRemove], "Not a treasurer");
        treasurers[treasurerToRemove] = false;
        emit TreasurerRemoved(treasurerToRemove);
    }
    
    function pause() external onlyAdmin {
        require(!paused, "Already paused");
        paused = true;
        emit ContractPaused(msg.sender);
    }
    
    function unpause() external onlyAdmin {
        require(paused, "Not paused");
        paused = false;
        emit ContractUnpaused(msg.sender);
    }
    
    function setRequiredConfirmations(uint8 confirmations) external onlyAdmin {
        require(confirmations >= 1 && confirmations <= 100, "Invalid confirmations");
        uint8 old = requiredConfirmations;
        requiredConfirmations = confirmations;
        emit ConfirmationsUpdated(old, confirmations);
    }
    
    function setDailyWithdrawalLimit(uint256 limit) external onlyAdmin {
        require(limit > 0 && limit <= 50 ether, "Limit must be between 0 and 50 ETH");
        uint256 old = dailyWithdrawalLimit;
        dailyWithdrawalLimit = limit;
        emit WithdrawalLimitUpdated(old, limit);
    }
    
    receive() external payable {
        // Allow receiving ETH
    }
}
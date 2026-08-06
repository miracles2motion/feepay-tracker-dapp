URL https://feepaydapp.netlify.app/
FeePay - Smart Contract Documentation

📚 Overview

FeePay is a decentralized school fees payment smart contract built on Ethereum. Students self-register using their wallet addresses and pay various fees directly on-chain with role-based access control.

🚀 Features

· Self-Registration: Students register themselves using their wallet
· Fee Management: 7 configurable fee types (TUITION, HOSTEL, LIBRARY, LAB, SPORTS, EXAMINATION, OTHER)
· Payment System: On-chain payments with tracking and confirmation
· Role-Based Access: Owner, Admin, Treasurer, and Student roles
· Security: Pause functionality, withdrawal limits, input validation

📁 Contract Structure

```
FeePay.sol
├── Enums & Structs
│   ├── PaymentStatus
│   ├── FeeType (7 types)
│   ├── Semester
│   └── AccountStatus
│
├── State Variables
│   ├── Student Management
│   ├── Fee Management
│   ├── Payment Tracking
│   └── Admin/System
│
├── Modifiers
│   ├── onlyOwner
│   ├── onlyAdmin
│   ├── onlyTreasurer
│   ├── whenNotPaused
│   ├── studentExists
│   ├── studentActive
│   ├── validStudent
│   └── validFeeType
│
└── Functions
    ├── Student Functions (8)
    ├── Admin Functions (10)
    ├── Treasury Functions (2)
    └── View Functions (15)
```

🎯 Contract Addresses

Network Address Status
Sepolia 0x... Deployed
Mainnet 0x... Pending

📊 Fee Types & Amounts

Fee Type Enum Value Amount (ETH) Description
TUITION 0 0.05 Tuition Fee
HOSTEL 1 0.025 Hostel Accommodation
LIBRARY 2 0.01 Library Services
LAB 3 0.015 Computer Laboratory
SPORTS 4 0.008 Sports Activities
EXAMINATION 5 0.012 Examination Fee
OTHER 6 0.01 Other Fees

🔐 Roles & Permissions

Owner

· Full contract control
· Add/remove admins
· Emergency withdrawal

Admin

· Manage students (suspend/reactivate)
· Update fee schedules
· Confirm/refund payments
· Pause/unpause contract
· Add/remove treasurers

Treasurer

· Withdraw collected fees
· Subject to daily limits

Student

· Self-registration
· Pay fees
· View their data
· Update profile

📖 Function Reference

Student Functions

registerStudent(string username, string institution, string email, string profileHash)

Registers a new student.

Parameters:

· username: Unique username (3-30 chars, alphanumeric + _ .)
· institution: Institution name (max 100 chars)
· email: Valid email format (optional)
· profileHash: IPFS hash for profile data (optional)

Requirements:

· Not already registered
· Username not taken
· Valid email format (if provided)

Emits: StudentRegistered

---

login()

Tracks student login activity.

Requirements:

· Student must be registered

Emits: StudentLoggedIn

---

updateProfile(string email, string profileHash)

Updates student profile information.

Parameters:

· email: New email address (optional)
· profileHash: New profile hash (optional)

Requirements:

· Student must be registered and active
· Valid email format (if provided)

Emits: StudentUpdated

---

payFee(FeeType feeType, Semester semester, string academicSession, string transactionHash, string notes)

Pays a fee.

Parameters:

· feeType: Type of fee (0-6)
· semester: Semester (0-3)
· academicSession: Session string (e.g., "2024-2025")
· transactionHash: External transaction reference
· notes: Payment notes

Requirements:

· Student must be registered and active
· Fee type must be active
· Fee not already paid
· Valid academic session
· Sufficient ETH sent

Emits: PaymentSubmitted

---

Admin Functions

suspendStudent(address wallet)

Suspends a student account.

Requirements:

· Admin only
· Student must be registered
· Not already suspended

Emits: StudentSuspended

---

reactivateStudent(address wallet)

Reactivates a suspended student account.

Requirements:

· Admin only
· Student must be suspended

Emits: StudentReactivated

---

updateFeeSchedule(FeeType feeType, uint256 amount, string description)

Updates fee amount for a fee type.

Parameters:

· feeType: Fee type to update
· amount: New fee amount (between MIN_FEE and MAX_FEE)
· description: Fee description

Requirements:

· Admin only
· Contract not paused
· Amount within limits

Emits: FeeScheduleUpdated

---

toggleFeeType(FeeType feeType, bool isActive)

Enables or disables a fee type.

Requirements:

· Admin only

Emits: FeeTypeToggled

---

confirmPayment(uint256 paymentId)

Confirms a pending payment.

Requirements:

· Admin only
· Payment must be pending

Emits: PaymentConfirmed

---

refundPayment(uint256 paymentId)

Refunds a payment.

Requirements:

· Admin only
· Contract not paused
· Payment not already refunded

Emits: PaymentRefunded

---

pause()

Pauses the contract.

Requirements:

· Admin only
· Contract not already paused

Emits: ContractPaused

---

unpause()

Unpauses the contract.

Requirements:

· Admin only
· Contract must be paused

Emits: ContractUnpaused

---

Treasury Functions

withdrawFees(FeeType feeType)

Withdraws collected fees for a fee type.

Requirements:

· Treasurer only
· Contract not paused
· Funds available
· Daily limit not exceeded

Emits: FundsWithdrawn

---

emergencyWithdrawUntrackedFunds()

Withdraws untracked ETH from the contract.

Requirements:

· Owner only
· Contract not paused
· Untracked funds available

Emits: EmergencyWithdrawal

---

View Functions

isRegistered(address wallet) -> bool

Checks if a wallet is registered.

getStudentId(address wallet) -> string

Gets student ID from wallet address.

getStudentByWallet(address wallet) -> (string, string, string, string, uint256, uint256, AccountStatus)

Gets complete student profile by wallet.

getStudentById(string studentId) -> (address, string, string, string, uint256, uint256, AccountStatus)

Gets student profile by student ID.

getAllStudents() -> address[]

Returns all registered student addresses.

getStudentCount() -> uint256

Returns total number of registered students.

getFeeSchedules() -> FeeSchedule[]

Returns all fee schedules.

getFeeAmount(FeeType feeType) -> uint256

Returns fee amount for a fee type.

getPayment(uint256 paymentId) -> Payment

Returns payment details by ID.

getMyPayments() -> Payment[]

Returns all payments for the caller.

getPaymentsByStudent(string studentId) -> Payment[]

Returns all payments for a student.

getRecentPayments(uint256 limit) -> Payment[]

Returns recent payments.

getPendingCount() -> uint256

Returns count of pending payments.

getTotalPaymentsCount() -> uint256

Returns total payments count.

getContractBalance() -> uint256

Returns contract's ETH balance.

getStudentFeeStatus(FeeType feeType) -> bool

Checks if caller has paid a specific fee.

---

🔧 Events

Event Parameters Description
StudentRegistered wallet, studentId, username, institution, timestamp Student registration
StudentUpdated wallet, field, value Profile update
StudentLoggedIn wallet, timestamp Login tracking
StudentSuspended wallet, admin Account suspended
StudentReactivated wallet, admin Account reactivated
FeeScheduleUpdated feeType, amount Fee updated
FeeTypeToggled feeType, isActive Fee enabled/disabled
FeeRecipientUpdated feeType, oldRecipient, newRecipient Recipient changed
PaymentSubmitted paymentId, payer, studentId, feeType, amount Payment made
PaymentConfirmed paymentId, confirmations Payment confirmed
PaymentRefunded paymentId, payer, amount Payment refunded
FundsWithdrawn feeType, recipient, amount Fees withdrawn
EmergencyWithdrawal recipient, amount Emergency withdrawal
AdminAdded admin Admin added
AdminRemoved admin Admin removed
TreasurerAdded treasurer Treasurer added
TreasurerRemoved treasurer Treasurer removed
ContractPaused admin Contract paused
ContractUnpaused admin Contract unpaused
WithdrawalLimitUpdated oldLimit, newLimit Daily limit updated
ConfirmationsUpdated oldConfirmations, newConfirmations Confirmations updated

---

🚨 Error Messages

Error Description
Not owner Caller is not the owner
Not admin Caller is not an admin
Not treasurer Caller is not a treasurer
Contract paused Contract is paused
Student not registered Wallet not registered
Account not active Student account suspended
Already registered Wallet already registered
Username already taken Username exists
Email already used Email exists
Invalid username format Invalid characters/length
Invalid email format Invalid email syntax
Fee type not active Fee type disabled
Fee already paid Fee already paid
Insufficient payment Not enough ETH sent
Overpayment too large Overpayment exceeds limit
Invalid session Invalid academic session
Daily withdrawal limit exceeded Daily limit reached
No funds to withdraw No fees collected
No recipient set Fee recipient not set

---

⚡ Gas Estimates

Function Gas Cost
registerStudent() ~386,000
payFee() ~841,000
confirmPayment() ~45,000
withdrawFees() ~45,000
getStudentByWallet() ~5,000
getFeeAmount() ~2,000

---

🔒 Security Features

1. Role-Based Access Control: Strict modifiers for sensitive functions
2. Pause Mechanism: Emergency stop for all operations
3. Withdrawal Limits: Daily limits prevent fund draining
4. Input Validation: All user inputs are validated
5. Reentrancy Protection: call() pattern with checks
6. Event Logging: All important actions are logged

---

📝 License

MIT License - see LICENSE file for details

---

Version: 1.0.0
Solidity Version: ^0.8.20
Network: Ethereum (Sepolia Testnet)

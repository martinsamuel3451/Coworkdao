# 🏢 Coworkdao - Decentralized Co-working Space Management

A blockchain-based DAO for managing shared office spaces with booking, membership, and governance features built on Stacks.

## 🚀 Features

- **👥 DAO Membership**: Join the DAO by paying membership fees
- **🏠 Space Management**: Add and manage co-working spaces
- **📅 Booking System**: Reserve spaces with hourly rates
- **💰 Balance Management**: Deposit and manage funds
- **🗳️ Governance**: Create and vote on proposals
- **⚡ Real-time Availability**: Track space availability

## 📋 Contract Functions

### Public Functions

#### Membership
- `join-dao()` - Join the DAO by paying membership fee
- `deposit-funds(amount)` - Add funds to your account balance

#### Space Management
- `add-space(name, capacity, hourly-rate)` - Add a new co-working space
- `book-space(space-id, start-time, duration)` - Book a space for specified duration
- `end-booking(booking-id)` - End an active booking

#### Governance
- `create-proposal(title, description)` - Create a new governance proposal
- `vote-on-proposal(proposal-id, vote-for)` - Vote on existing proposals

#### Admin Functions
- `update-membership-fee(new-fee)` - Update DAO membership fee
- `update-booking-fee(new-fee)` - Update booking fee structure

### Read-Only Functions

- `get-space(space-id)` - Get space details
- `get-booking(booking-id)` - Get booking information
- `get-member(user)` - Get member details
- `get-proposal(proposal-id)` - Get proposal information
- `get-balance(user)` - Get user's account balance
- `get-membership-fee()` - Get current membership fee
- `get-booking-fee()` - Get current booking fee
- `is-member(user)` - Check if user is a DAO member
- `get-user-vote(proposal-id, voter)` - Get user's vote on a proposal

## 🛠️ Usage Instructions

### 1. Deploy the Contract
```bash
clarinet deploy
```

### 2. Join the DAO
First, deposit funds and then join:
```bash
(contract-call? .Coworkdao deposit-funds u5000000)
(contract-call? .Coworkdao join-dao)
```

### 3. Add a Co-working Space
```bash
(contract-call? .Coworkdao add-space "Main Conference Room" u10 u50000)
```

### 4. Book a Space
```bash
(contract-call? .Coworkdao book-space u1 u1000 u4)
```

### 5. Create and Vote on Proposals
```bash
(contract-call? .Coworkdao create-proposal "Upgrade WiFi" "Proposal to upgrade internet speed")
(contract-call? .Coworkdao vote-on-proposal u1 true)
```

## 💡 Key Concepts

- **Membership**: Users must join the DAO to access features
- **Voting Power**: Increases with booking activity
- **Space Availability**: Automatically managed during bookings
- **Governance**: Democratic decision-making through proposals
- **Balance Management**: Internal accounting system for payments

## 🔧 Error Codes

- `u100` - Not authorized
- `u101` - Space not found
- `u102` - Space occupied
- `u103` - Insufficient balance
- `u104` - Booking not found
- `u105` - Invalid time
- `u106` - Not a member
- `u107` - Proposal not found
- `u108` - Already voted
- `u109` - Voting period ended

## 🏗️ Development

Built with Clarinet for the Stacks blockchain. The contract uses modern Clarity syntax including `stacks-block-height` for time-based operations.

## 📄 License

MIT License - Build the future of co-working! 🌟


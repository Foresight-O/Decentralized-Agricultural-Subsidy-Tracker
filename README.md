# 🌾 Decentralized Agricultural Subsidy Tracker

A transparent blockchain-based system for managing agricultural subsidies using Clarity smart contracts on Stacks.

## 🎯 Features

- 👨‍🌾 Farmer registration and verification
- 💰 Subsidy program creation and management  
- ✅ Verifier management system
- 📊 Transparent subsidy distribution tracking
- 🔐 Admin controls for program oversight

## 📝 Contract Functions

### Farmer Management
- `register-farmer`: Register new farmers with their details
- `verify-farmer`: Verify farmer credentials by authorized verifiers

### Subsidy Management  
- `create-subsidy`: Create new subsidy programs
- `distribute-subsidy`: Distribute subsidies to eligible farmers
- `deactivate-subsidy`: Deactivate subsidy programs

### Administration
- `set-admin`: Update contract administrator
- `add-verifier`: Add authorized verifiers

## 🚀 Getting Started

1. Install [Clarinet](https://github.com/hirosystems/clarinet)
2. Clone this repository
3. Run tests: `clarinet test`
4. Deploy contract using Clarinet console

## 📊 Data Structures

- Farmers: Stores farmer details and verification status
- Subsidies: Manages subsidy program information
- Verifiers: Tracks authorized verification entities
- Farmer-subsidies: Records subsidy distribution history

## 🔒 Security

- Role-based access control
- Verification requirements
- Double-distribution prevention
- Admin-only sensitive operations
```
# 💝 Charity Donation Tracker

A transparent blockchain-based charity donation tracking system built on Stacks using Clarity smart contracts.

## 🎯 Features

- 🏛️ **Charity Registration**: Organizations can register and manage their profiles
- 💰 **Secure Donations**: Direct STX transfers to charity wallets with full transparency
- 📊 **Real-time Tracking**: Monitor donations, balances, and withdrawal history
- 🔍 **Verification System**: Verify donations and charity legitimacy
- 📈 **Performance Metrics**: Track donation efficiency and impact analytics
- 🔐 **Ownership Transfer**: Charities can transfer ownership to new wallets

## 🚀 Quick Start

### Prerequisites
- [Clarinet](https://docs.hiro.so/clarinet) installed
- Node.js for testing

### Installation
```bash
git clone https://github.com/ogunleyenadia/Charity-Donation-Tracker
cd Charity-Donation-Tracker
clarinet check
```

## 📋 Usage

### For Charities

#### 1. Register Your Charity 🏛️
```clarity
(contract-call? .Charity-Donation-Tracker register-charity 
  "My Charity Name" 
  "We help communities in need" 
  "Community")
```

#### 2. Update Charity Information ✏️
```clarity
(contract-call? .Charity-Donation-Tracker update-charity-info 
  u1 
  "Updated Name" 
  "Updated description" 
  "Education")
```

#### 3. Withdraw Funds 💸
```clarity
(contract-call? .Charity-Donation-Tracker withdraw-funds u1000000)
```

#### 4. Deactivate/Reactivate 🔄
```clarity
(contract-call? .Charity-Donation-Tracker deactivate-charity u1)
(contract-call? .Charity-Donation-Tracker reactivate-charity u1)
```

### For Donors

#### 1. Make a Donation 💖
```clarity
(contract-call? .Charity-Donation-Tracker donate 
  u1 
  u500000 
  (some "Keep up the great work!"))
```

#### 2. Check Your Donation History 📝
```clarity
(contract-call? .Charity-Donation-Tracker get-donor-stats 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

### Read-Only Functions 👀

#### Get Charity Information
```clarity
(contract-call? .Charity-Donation-Tracker get-charity u1)
(contract-call? .Charity-Donation-Tracker get-charity-by-wallet 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

#### Check Balances 💰
```clarity
(contract-call? .Charity-Donation-Tracker get-charity-balance u1)
(contract-call? .Charity-Donation-Tracker get-charity-stats u1)
```

#### Platform Statistics 📊
```clarity
(contract-call? .Charity-Donation-Tracker get-platform-metrics)
(contract-call? .Charity-Donation-Tracker get-contract-stats)
```

#### Verify Donations ✅
```clarity
(contract-call? .Charity-Donation-Tracker verify-donation 
  u1 
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM 
  u500000)
```

## 🏗️ Contract Structure

### Data Maps
- **charities**: Core charity information and statistics
- **charity-by-wallet**: Quick lookup by wallet address
- **donations**: Individual donation records
- **donor-stats**: Aggregated donor statistics
- **charity-withdrawals**: Withdrawal history tracking

### Key Functions

| Function | Type | Description |
|----------|------|-------------|
| `register-charity` | Public | Register new charity organization |
| `donate` | Public | Make donation to registered charity |
| `withdraw-funds` | Public | Charity withdraws available funds |
| `get-charity-stats` | Read-only | Comprehensive charity information |
| `get-donation-summary` | Read-only | Donor's complete donation history |
| `verify-donation` | Read-only | Verify specific donation details |

## 🔒 Security Features

- ✅ Self-donation prevention
- ✅ Authorization checks for charity operations
- ✅ Active status validation
- ✅ Balance verification before withdrawals
- ✅ Input validation and sanitization

## 📊 Analytics & Reporting

- 📈 Charity performance metrics
- 💡 Donation impact calculations
- 🏆 Platform-wide statistics
- 📋 Batch charity verification
- ⚡ Gas cost estimation

## 🧪 Testing

```bash
npm install
npm test
```

## 📄 Error Codes

| Code | Description |
|------|-------------|
| u100 | Not authorized |
| u101 | Charity not found |
| u102 | Charity already exists |
| u103 | Invalid amount |
| u104 | Insufficient balance |
| u105 | Charity not active |
| u106 | Self-donation not allowed |


## 📞 Support

For questions or support, please open an issue on GitHub.

---

*Built with ❤️ for transparent charitable giving on Stacks blockchain*

# Voting DApp

A comprehensive decentralized voting application built on Ethereum with advanced features including delegate voting, time locks, and proposal management.

## Features

### Core Voting Functionality
- **Proposal Creation**: Create proposals with customizable duration and quorum requirements
- **Multiple Vote Types**: Support for Yes, No, and Abstain votes
- **Vote Verification**: Secure vote counting with prevention of double voting
- **Quorum Requirements**: Configurable minimum vote thresholds

### Advanced Features
- **Delegate Voting**: Allow voters to delegate their voting power to trusted representatives
- **Time Locks**: Execution delay mechanism for enhanced security
- **Vote History**: Complete audit trail of all voting activities
- **Proposal Management**: Create, cancel, and execute proposals with proper permissions

### Security Features
- **Reentrancy Protection**: Prevents reentrancy attacks
- **Pausable**: Emergency pause functionality
- **Access Control**: Role-based permissions for administrative functions
- **Input Validation**: Comprehensive parameter validation

## Smart Contract Architecture

### Key Components

1. **Proposal Management**
   - Create proposals with title, description, duration, and quorum
   - Track proposal states (Active, Executed, Canceled, Expired)
   - Execute proposals after voting period and time lock

2. **Voting System**
   - Weighted voting based on voting power
   - Delegate voting mechanism
   - Vote history tracking
   - Prevention of double voting

3. **Administrative Functions**
   - Manage voter registration and voting power
   - Configure system parameters (quorum, execution delay)
   - Emergency functions for crisis management

## Contract Functions

### Core Functions
- `createProposal()` - Create a new voting proposal
- `vote()` - Cast a vote on an active proposal
- `delegate()` - Delegate voting power to another address
- `executeProposal()` - Execute a passed proposal
- `cancelProposal()` - Cancel a proposal (creator only)

### View Functions
- `getProposal()` - Get proposal details
- `getVoter()` - Get voter information
- `getEffectiveVotingPower()` - Calculate total voting power including delegations
- `getProposalState()` - Get current proposal state
- `getVoteHistory()` - Get voting history for an address

### Admin Functions
- `setVotingPower()` - Assign or update voter voting power
- `setQuorum()` - Update quorum requirements
- `setExecutionDelay()` - Update time lock delay
- `pause()` / `unpause()` - Emergency pause functionality

## Installation & Setup

### Prerequisites
- Node.js (v16 or higher)
- npm or yarn

### Installation
```bash
# Install dependencies
npm install

# Compile contracts
npm run compile

# Run tests
npm test

# Start local blockchain
npm run node
```

### Deployment
```bash
# Deploy to local network
npm run deploy
```

## Usage Examples

### Creating a Proposal
```solidity
// Create a proposal with 7-day voting period and 1000 vote quorum
votingContract.createProposal(
    "Increase Treasury Allocation",
    "Proposal to increase treasury allocation by 20%",
    7 days,
    1000
);
```

### Casting a Vote
```solidity
// Vote Yes on proposal ID 1
votingContract.vote(1, VoteChoice.Yes);
```

### Delegating Voting Power
```solidity
// Delegate voting power to another address
votingContract.delegate(0x1234...);
```

## Security Considerations

1. **Time Locks**: All proposals have a mandatory execution delay
2. **Quorum Requirements**: Proposals must meet minimum participation thresholds
3. **Access Control**: Administrative functions are restricted to contract owner
4. **Input Validation**: All parameters are validated before processing
5. **Reentrancy Protection**: Contract is protected against reentrancy attacks

## Gas Optimization

The contract includes several gas optimization features:
- Efficient storage patterns
- Optimized loops and mappings
- Minimal external calls
- Compiler optimizations enabled

## Testing

Run the test suite:
```bash
npm test
```

The test suite covers:
- Proposal creation and management
- Voting functionality
- Delegate voting
- Administrative functions
- Security scenarios
- Edge cases

## License

MIT License - see LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## Support

For questions and support, please open an issue on GitHub.

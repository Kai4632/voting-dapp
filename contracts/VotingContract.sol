// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title VotingContract
 * @dev A comprehensive voting DApp smart contract with delegate voting, time locks, and proposal management
 * @author Voting DApp Team
 */
contract VotingContract is Ownable, ReentrancyGuard, Pausable {
    
    // ============ STRUCTS ============
    
    struct Proposal {
        uint256 id;
        string title;
        string description;
        uint256 startTime;
        uint256 endTime;
        uint256 yesVotes;
        uint256 noVotes;
        uint256 abstainVotes;
        bool executed;
        bool canceled;
        address creator;
        uint256 quorum;
        uint256 minVotingPeriod;
        uint256 maxVotingPeriod;
    }
    
    struct Voter {
        uint256 votingPower;
        bool hasVoted;
        uint256 votedProposalId;
        VoteChoice voteChoice;
        address delegate;
        bool isDelegate;
        uint256 delegatedVotingPower;
        uint256 lastVoteTime;
    }
    
    struct VoteHistory {
        uint256 proposalId;
        VoteChoice choice;
        uint256 votingPower;
        uint256 timestamp;
    }
    
    enum VoteChoice { None, Yes, No, Abstain }
    enum ProposalState { Active, Executed, Canceled, Expired }
    
    // ============ STATE VARIABLES ============
    
    uint256 public proposalCount;
    uint256 public totalVotingPower;
    uint256 public minProposalDuration = 1 days;
    uint256 public maxProposalDuration = 30 days;
    uint256 public defaultQuorum = 1000; // Minimum votes required
    uint256 public executionDelay = 1 days; // Time lock delay
    
    mapping(uint256 => Proposal) public proposals;
    mapping(address => Voter) public voters;
    mapping(address => VoteHistory[]) public voteHistory;
    mapping(address => address[]) public delegators;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(uint256 => mapping(VoteChoice => uint256)) public voteCounts;
    
    // ============ EVENTS ============
    
    event ProposalCreated(
        uint256 indexed proposalId,
        string title,
        address indexed creator,
        uint256 startTime,
        uint256 endTime,
        uint256 quorum
    );
    
    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        VoteChoice choice,
        uint256 votingPower
    );
    
    event VoteDelegated(
        address indexed delegator,
        address indexed delegate,
        uint256 votingPower
    );
    
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCanceled(uint256 indexed proposalId);
    event VotingPowerUpdated(address indexed voter, uint256 newPower);
    event QuorumUpdated(uint256 newQuorum);
    event ExecutionDelayUpdated(uint256 newDelay);
    
    // ============ MODIFIERS ============
    
    modifier onlyVoter() {
        require(voters[msg.sender].votingPower > 0, "Not a registered voter");
        _;
    }
    
    modifier proposalExists(uint256 proposalId) {
        require(proposalId > 0 && proposalId <= proposalCount, "Proposal does not exist");
        _;
    }
    
    modifier proposalActive(uint256 proposalId) {
        require(
            proposals[proposalId].startTime <= block.timestamp &&
            proposals[proposalId].endTime > block.timestamp &&
            !proposals[proposalId].executed &&
            !proposals[proposalId].canceled,
            "Proposal is not active"
        );
        _;
    }
    
    modifier onlyProposalCreator(uint256 proposalId) {
        require(proposals[proposalId].creator == msg.sender, "Not proposal creator");
        _;
    }
    
    modifier executionDelayPassed(uint256 proposalId) {
        require(
            block.timestamp >= proposals[proposalId].endTime + executionDelay,
            "Execution delay not passed"
        );
        _;
    }
    
    // ============ CONSTRUCTOR ============
    
    constructor() {
        proposalCount = 0;
        totalVotingPower = 0;
    }
    
    // ============ CORE FUNCTIONS ============
    
    /**
     * @dev Create a new proposal
     * @param title Proposal title
     * @param description Proposal description
     * @param duration Voting duration in seconds
     * @param quorum Minimum votes required for proposal to pass
     */
    function createProposal(
        string memory title,
        string memory description,
        uint256 duration,
        uint256 quorum
    ) external onlyVoter whenNotPaused {
        require(bytes(title).length > 0, "Title cannot be empty");
        require(duration >= minProposalDuration, "Duration too short");
        require(duration <= maxProposalDuration, "Duration too long");
        require(quorum > 0, "Quorum must be greater than 0");
        
        proposalCount++;
        
        proposals[proposalCount] = Proposal({
            id: proposalCount,
            title: title,
            description: description,
            startTime: block.timestamp,
            endTime: block.timestamp + duration,
            yesVotes: 0,
            noVotes: 0,
            abstainVotes: 0,
            executed: false,
            canceled: false,
            creator: msg.sender,
            quorum: quorum,
            minVotingPeriod: minProposalDuration,
            maxVotingPeriod: maxProposalDuration
        });
        
        emit ProposalCreated(
            proposalCount,
            title,
            msg.sender,
            block.timestamp,
            block.timestamp + duration,
            quorum
        );
    }
    
    /**
     * @dev Cast a vote on a proposal
     * @param proposalId ID of the proposal to vote on
     * @param choice Vote choice (Yes, No, or Abstain)
     */
    function vote(
        uint256 proposalId,
        VoteChoice choice
    ) external onlyVoter proposalExists(proposalId) proposalActive(proposalId) whenNotPaused {
        require(choice != VoteChoice.None, "Invalid vote choice");
        require(!hasVoted[proposalId][msg.sender], "Already voted");
        
        uint256 votingPower = getEffectiveVotingPower(msg.sender);
        require(votingPower > 0, "No voting power");
        
        // Record the vote
        hasVoted[proposalId][msg.sender] = true;
        voters[msg.sender].hasVoted = true;
        voters[msg.sender].votedProposalId = proposalId;
        voters[msg.sender].voteChoice = choice;
        voters[msg.sender].lastVoteTime = block.timestamp;
        
        // Update vote counts
        if (choice == VoteChoice.Yes) {
            proposals[proposalId].yesVotes += votingPower;
        } else if (choice == VoteChoice.No) {
            proposals[proposalId].noVotes += votingPower;
        } else if (choice == VoteChoice.Abstain) {
            proposals[proposalId].abstainVotes += votingPower;
        }
        
        // Record vote history
        voteHistory[msg.sender].push(VoteHistory({
            proposalId: proposalId,
            choice: choice,
            votingPower: votingPower,
            timestamp: block.timestamp
        }));
        
        emit VoteCast(proposalId, msg.sender, choice, votingPower);
    }
    
    /**
     * @dev Delegate voting power to another address
     * @param delegate Address to delegate voting power to
     */
    function delegate(address delegate) external onlyVoter whenNotPaused {
        require(delegate != address(0), "Invalid delegate address");
        require(delegate != msg.sender, "Cannot delegate to self");
        require(voters[delegate].votingPower > 0, "Delegate must be a voter");
        
        Voter storage voter = voters[msg.sender];
        require(voter.delegate == address(0), "Already delegated");
        
        // Update delegation
        voter.delegate = delegate;
        voters[delegate].isDelegate = true;
        voters[delegate].delegatedVotingPower += voter.votingPower;
        delegators[delegate].push(msg.sender);
        
        emit VoteDelegated(msg.sender, delegate, voter.votingPower);
    }
    
    /**
     * @dev Execute a proposal if it has passed
     * @param proposalId ID of the proposal to execute
     */
    function executeProposal(
        uint256 proposalId
    ) external proposalExists(proposalId) executionDelayPassed(proposalId) whenNotPaused {
        Proposal storage proposal = proposals[proposalId];
        
        require(!proposal.executed, "Proposal already executed");
        require(!proposal.canceled, "Proposal was canceled");
        require(proposal.endTime < block.timestamp, "Voting period not ended");
        
        uint256 totalVotes = proposal.yesVotes + proposal.noVotes + proposal.abstainVotes;
        require(totalVotes >= proposal.quorum, "Quorum not reached");
        
        bool passed = proposal.yesVotes > proposal.noVotes;
        
        if (passed) {
            proposal.executed = true;
            emit ProposalExecuted(proposalId);
        }
    }
    
    /**
     * @dev Cancel a proposal (only creator can cancel)
     * @param proposalId ID of the proposal to cancel
     */
    function cancelProposal(
        uint256 proposalId
    ) external onlyProposalCreator(proposalId) proposalExists(proposalId) whenNotPaused {
        Proposal storage proposal = proposals[proposalId];
        
        require(!proposal.executed, "Proposal already executed");
        require(!proposal.canceled, "Proposal already canceled");
        require(proposal.endTime > block.timestamp, "Voting period ended");
        
        proposal.canceled = true;
        emit ProposalCanceled(proposalId);
    }
    
    // ============ VIEW FUNCTIONS ============
    
    /**
     * @dev Get proposal details
     * @param proposalId ID of the proposal
     * @return Proposal details
     */
    function getProposal(
        uint256 proposalId
    ) external view proposalExists(proposalId) returns (Proposal memory) {
        return proposals[proposalId];
    }
    
    /**
     * @dev Get voter information
     * @param voter Address of the voter
     * @return Voter details
     */
    function getVoter(address voter) external view returns (Voter memory) {
        return voters[voter];
    }
    
    /**
     * @dev Get effective voting power (including delegated power)
     * @param voter Address of the voter
     * @return Effective voting power
     */
    function getEffectiveVotingPower(address voter) public view returns (uint256) {
        Voter storage voterInfo = voters[voter];
        uint256 power = voterInfo.votingPower;
        
        // Add delegated voting power if this address is a delegate
        if (voterInfo.isDelegate) {
            power += voterInfo.delegatedVotingPower;
        }
        
        return power;
    }
    
    /**
     * @dev Get proposal state
     * @param proposalId ID of the proposal
     * @return Current state of the proposal
     */
    function getProposalState(uint256 proposalId) external view returns (ProposalState) {
        Proposal storage proposal = proposals[proposalId];
        
        if (proposal.canceled) return ProposalState.Canceled;
        if (proposal.executed) return ProposalState.Executed;
        if (proposal.endTime < block.timestamp) return ProposalState.Expired;
        return ProposalState.Active;
    }
    
    /**
     * @dev Get vote history for a voter
     * @param voter Address of the voter
     * @return Array of vote history entries
     */
    function getVoteHistory(address voter) external view returns (VoteHistory[] memory) {
        return voteHistory[voter];
    }
    
    /**
     * @dev Get delegators for a delegate
     * @param delegate Address of the delegate
     * @return Array of delegator addresses
     */
    function getDelegators(address delegate) external view returns (address[] memory) {
        return delegators[delegate];
    }
    
    /**
     * @dev Check if a voter has voted on a specific proposal
     * @param proposalId ID of the proposal
     * @param voter Address of the voter
     * @return True if the voter has voted
     */
    function hasVotedOnProposal(uint256 proposalId, address voter) external view returns (bool) {
        return hasVoted[proposalId][voter];
    }
    
    // ============ ADMIN FUNCTIONS ============
    
    /**
     * @dev Add or update voter with voting power (admin only)
     * @param voter Address of the voter
     * @param votingPower Voting power to assign
     */
    function setVotingPower(address voter, uint256 votingPower) external onlyOwner {
        require(voter != address(0), "Invalid voter address");
        
        uint256 oldPower = voters[voter].votingPower;
        voters[voter].votingPower = votingPower;
        
        totalVotingPower = totalVotingPower - oldPower + votingPower;
        
        emit VotingPowerUpdated(voter, votingPower);
    }
    
    /**
     * @dev Update quorum requirement (admin only)
     * @param newQuorum New quorum value
     */
    function setQuorum(uint256 newQuorum) external onlyOwner {
        require(newQuorum > 0, "Quorum must be greater than 0");
        defaultQuorum = newQuorum;
        emit QuorumUpdated(newQuorum);
    }
    
    /**
     * @dev Update execution delay (admin only)
     * @param newDelay New execution delay in seconds
     */
    function setExecutionDelay(uint256 newDelay) external onlyOwner {
        executionDelay = newDelay;
        emit ExecutionDelayUpdated(newDelay);
    }
    
    /**
     * @dev Update proposal duration limits (admin only)
     * @param minDuration Minimum proposal duration
     * @param maxDuration Maximum proposal duration
     */
    function setProposalDurationLimits(uint256 minDuration, uint256 maxDuration) external onlyOwner {
        require(minDuration < maxDuration, "Min duration must be less than max duration");
        minProposalDuration = minDuration;
        maxProposalDuration = maxDuration;
    }
    
    /**
     * @dev Pause the contract (admin only)
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev Unpause the contract (admin only)
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    // ============ EMERGENCY FUNCTIONS ============
    
    /**
     * @dev Emergency function to remove voter (admin only)
     * @param voter Address of the voter to remove
     */
    function emergencyRemoveVoter(address voter) external onlyOwner {
        require(voter != address(0), "Invalid voter address");
        
        uint256 votingPower = voters[voter].votingPower;
        delete voters[voter];
        
        totalVotingPower -= votingPower;
        
        emit VotingPowerUpdated(voter, 0);
    }
    
    /**
     * @dev Emergency function to cancel proposal (admin only)
     * @param proposalId ID of the proposal to cancel
     */
    function emergencyCancelProposal(uint256 proposalId) external onlyOwner proposalExists(proposalId) {
        Proposal storage proposal = proposals[proposalId];
        
        require(!proposal.executed, "Proposal already executed");
        require(!proposal.canceled, "Proposal already canceled");
        
        proposal.canceled = true;
        emit ProposalCanceled(proposalId);
    }
} 
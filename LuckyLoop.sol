// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LuckyLoop is ReentrancyGuard, Ownable {
    // Immutable wallets (matches your TX records)
    address public immutable prizePoolWallet = 0xdD758F645E3D182859109Fa6a07E9Fc4757d1802;
    address public immutable profitWallet = 0x31Bd345293BB862A913935551ce0a0101efE5194;

    // Tier constants (aligned with frontend values)
    uint256 public constant TIER1_ENTRY_FEE = 0.00125 ether; // $5
    uint256 public constant TIER1_PRIZE_AMOUNT = 0.025 ether; // $100
    uint256 public constant TIER1_PROFIT_AMOUNT = 0.0125 ether; // $50
    uint256 public constant TIER1_MAX_PARTICIPANTS = 100;

    uint256 public constant TIER2_ENTRY_FEE = 0.0125 ether; // $50
    uint256 public constant TIER2_PRIZE_AMOUNT = 0.25 ether; // $1000
    uint256 public constant TIER2_PROFIT_AMOUNT = 0.125 ether; // $500
    uint256 public constant TIER2_MAX_PARTICIPANTS = 100;

    // State tracking (matches frontend display)
    mapping(uint256 => address[]) public tierParticipants;
    mapping(uint256 => mapping(address => bool)) public hasEntered;
    mapping(uint256 => bool) public isTierActive;

    event Entered(uint256 tier, address participant);
    event WinnerSelected(uint256 tier, address winner);
    event FundsDistributed(uint256 prizeAmount, uint256 profitAmount);

    constructor() {
        isTierActive[1] = true;
        isTierActive[2] = true;
    }

    function enterLottery(uint256 tier) external payable nonReentrant {
        require(tier == 1 || tier == 2, "Invalid tier");
        require(isTierActive[tier], "Tier inactive");
        require(!hasEntered[tier][msg.sender], "Already entered");

        if (tier == 1) {
            require(msg.value >= TIER1_ENTRY_FEE, "Insufficient Tier 1 fee");
        } else {
            require(msg.value >= TIER2_ENTRY_FEE, "Insufficient Tier 2 fee");
        }

        tierParticipants[tier].push(msg.sender);
        hasEntered[tier][msg.sender] = true;

        if (tierParticipants[tier].length == (tier == 1 ? TIER1_MAX_PARTICIPANTS : TIER2_MAX_PARTICIPANTS)) {
            _drawWinner(tier);
        }

        emit Entered(tier, msg.sender);
    }

    function _drawWinner(uint256 tier) internal {
        uint256 prizeAmount = tier == 1 ? TIER1_PRIZE_AMOUNT : TIER2_PRIZE_AMOUNT;
        uint256 profitAmount = tier == 1 ? TIER1_PROFIT_AMOUNT : TIER2_PROFIT_AMOUNT;
        
        address winner = tierParticipants[tier][_randomIndex(tier)];
        
        (bool sentPrize, ) = winner.call{value: prizeAmount}("");
        (bool sentProfit, ) = profitWallet.call{value: profitAmount}("");
        require(sentPrize && sentProfit, "Transfer failed");

        emit WinnerSelected(tier, winner);
        emit FundsDistributed(prizeAmount, profitAmount);

        // Reset tier
        delete tierParticipants[tier];
    }

    function _randomIndex(uint256 tier) internal view returns (uint256) {
        return uint256(
            keccak256(
                abi.encodePacked(
                    blockhash(block.number - 1),
                    block.timestamp,
                    tierParticipants[tier]
                )
            )
        ) % (tier == 1 ? TIER1_MAX_PARTICIPANTS : TIER2_MAX_PARTICIPANTS);
    }

    function getParticipantCount(uint256 tier) external view returns (uint256) {
        return tierParticipants[tier].length;
    }

    // Emergency drain (owner only)
    function emergencyWithdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    receive() external payable {}
}

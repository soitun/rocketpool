pragma solidity 0.7.6;

// SPDX-License-Identifier: GPL-3.0-only

import "../RocketBase.sol";
import "../../interface/token/RocketTokenRPLInterface.sol";
import "../../interface/rewards/RocketRewardsPoolInterface.sol";
import "../../interface/dao/protocol/settings/RocketDAOProtocolSettingsRewardsInterface.sol";
import "../../interface/RocketVaultInterface.sol";

import "@openzeppelin/contracts/math/SafeMath.sol";


// Holds RPL generated by the network for claiming from stakers (node operators etc)

contract RocketRewardsPool is RocketBase, RocketRewardsPoolInterface {

    // Our base calc
    uint256 calcBase = 1 ether; 

    // Libs
    using SafeMath for uint;


    // Events
    event RPLTokensClaimed(address indexed claimingContract, address indexed claimingAddress, uint256 amount, uint256 time);  
    
    // Modifiers

    /**
    * @dev Throws if called by any sender that doesn't match a Rocket Pool claim contract
    */
    modifier onlyClaimContract() {
        require(getClaimingContractExists(getContractName(msg.sender)), "Not a valid rewards claiming contact");
        _;
    }

    /**
    * @dev Throws if called by any sender that doesn't match an enabled Rocket Pool claim contract
    */
    modifier onlyEnabledClaimContract() {
        require(getClaimingContractEnabled(getContractName(msg.sender)), "Not a valid rewards claiming contact or it has been disabled");
        _;
    }


    // Construct
    constructor(RocketStorageInterface _rocketStorageAddress) RocketBase(_rocketStorageAddress) {
        // Version
        version = 1;
        // Set the claim interval start block as the deployment block
        setUintS("rewards.pool.claim.interval.block.start", block.number);
    }


    /**
    * Get how much RPL the Rewards Pool contract currently has assigned to it as a whole
    * @return bool Returns rpl balance of rocket rewards contract
    */
    function getRPLBalance() override public view returns(uint256) { 
        // Get the vault contract instance
        RocketVaultInterface rocketVault = RocketVaultInterface(getContractAddress('rocketVault'));
        // Check per contract
        return rocketVault.balanceOfToken('rocketRewardsPool', getContractAddress('rocketTokenRPL'));
    }


    /**
    * Get the last set interval start block
    * @return uint256 Last set start block for a claim interval
    */
    function getClaimIntervalBlockStart() override public view returns(uint256) {
        return getUintS("rewards.pool.claim.interval.block.start");
    }


    /**
    * Compute the current start block before a claim is made, takes into account intervals that may have passed
    * @return uint256 Computed starting block for next possible claim
    */
    function getClaimIntervalBlockStartComputed() override public view returns(uint256) {
        // If intervals have passed, a new start block will be used for the next claim, if it's the same interval then return that
        return getClaimIntervalsPassed() == 0 ? getClaimIntervalBlockStart() : getClaimIntervalBlockStart().add(getClaimIntervalBlocks().mul(getClaimIntervalsPassed()));
    }


    /**
    * Compute intervals since last claim period
    * @return uint256 Time intervals since last update
    */
    function getClaimIntervalsPassed() override public view returns(uint256) {
        // Calculate now if inflation has begun
        return block.number.sub(getClaimIntervalBlockStart()).div(getClaimIntervalBlocks());
    }


    /**
    * Get how many blocks in a claim interval
    * @return uint256 Number of blocks in a claim interval
    */
    function getClaimIntervalBlocks() override public view returns(uint256) {
        // Get from the DAO settings
        RocketDAOProtocolSettingsRewardsInterface daoSettingsRewards = RocketDAOProtocolSettingsRewardsInterface(getContractAddress('rocketDAOProtocolSettingsRewards'));
        return daoSettingsRewards.getRewardsClaimIntervalBlocks();
    }


    /**
    * Get the last block a claim was made
    * @return uint256 Last block a claim was made
    */
    function getClaimBlockLastMade() override public view returns(uint256) {
        return getUintS("rewards.pool.claim.interval.block.last");
    }


    // Check whether a claiming contract exists
    function getClaimingContractExists(string memory _contractName) override public view returns (bool) {
        RocketDAOProtocolSettingsRewardsInterface daoSettingsRewards = RocketDAOProtocolSettingsRewardsInterface(getContractAddress('rocketDAOProtocolSettingsRewards'));
        return (daoSettingsRewards.getRewardsClaimerPercBlockUpdated(_contractName) > 0);
    }


    // If the claiming contact has a % allocated to it higher than 0, it can claim
    function getClaimingContractEnabled(string memory _contractName) override public view returns (bool) {
        // Load contract
        RocketDAOProtocolSettingsRewardsInterface daoSettingsRewards = RocketDAOProtocolSettingsRewardsInterface(getContractAddress('rocketDAOProtocolSettingsRewards'));
        // Now verify this contract can claim by having a claim perc > 0 
        return daoSettingsRewards.getRewardsClaimerPerc(_contractName) > 0 ? true : false;
    }
    

    /**
    * The current claim amount total for this interval per claiming contract
    * @return uint256 The current claim amount for this interval for the claiming contract
    */
    function getClaimingContractTotalClaimed(string memory _claimingContract) override public view returns(uint256) {
        return getUint(keccak256(abi.encodePacked("rewards.pool.claim.interval.contract.total", getClaimIntervalBlockStartComputed(), _claimingContract)));
    }

    
    /**
    * Have they claimed already during this interval? 
    * @return bool Returns true if they can claim during this interval
    */
    function getClaimingContractUserHasClaimed(uint256 _claimIntervalStartBlock, string memory _claimingContract, address _claimerAddress) override public view returns(bool) {
        // Check per contract
        return getBool(keccak256(abi.encodePacked("rewards.pool.claim.interval.claimer.address", _claimIntervalStartBlock, _claimingContract, _claimerAddress)));
    }


    /**
    * Get the block number this account registered as a claimer at
    * @return uint256 Returns the block number the account was registered at
    */
    function getClaimingContractUserRegisteredBlock(string memory _claimingContract, address _claimerAddress) override public view returns(uint256) {
        return getUint(keccak256(abi.encodePacked("rewards.pool.claim.contract.registered.block", _claimingContract, _claimerAddress)));
    }

    
    /**
    * Get the block number this account registered as a claimer at
    * @return uint256 Returns the block number the account was registered at
    */
    function getClaimingContractUserCanClaim(string memory _claimingContract, address _claimerAddress) override public view returns(bool) {
        // Get the block they registered at
        uint256 registeredBlock = getClaimingContractUserRegisteredBlock(_claimingContract, _claimerAddress);
        // If it's 0 or hasn't passed one interval yet, they can't claim 
        return registeredBlock > 0 && registeredBlock.add(getClaimIntervalBlocks()) <= block.number && getClaimingContractPerc(_claimingContract) > 0 ? true : false;
    }


    /**
    * Get the number of claimers for the current interval per claiming contract
    * @return uint256 Returns number of claimers for the current interval per claiming contract
    */
    function getClaimingContractUserTotalCurrent(string memory _claimingContract) override public view returns(uint256) {
        // Return the current interval amount if in that interval, if we are moving to the next one upon next claim, use that
        return getClaimIntervalsPassed() == 0 ? getUint(keccak256(abi.encodePacked("rewards.pool.claim.interval.claimers.total.current", _claimingContract))) : getClaimingContractUserTotalNext(_claimingContract);
    }


    /**
    * Get the number of claimers that will be added/removed on the next interval
    * @return uint256 Returns the number of claimers that will be added/removed on the next interval
    */
    function getClaimingContractUserTotalNext(string memory _claimingContract) override public view returns(uint256) {
        return getUint(keccak256(abi.encodePacked("rewards.pool.claim.interval.claimers.total.next", _claimingContract)));
    }


    /**
    * Get contract claiming percentage last recorded
    * @return uint256 Returns the contract claiming percentage last recorded
    */
    function getClaimingContractPercLast(string memory _claimingContract) override public view returns(uint256) {
        return getUint(keccak256(abi.encodePacked("rewards.pool.claim.interval.contract.perc.current", _claimingContract)));
    }

   
    /**
    * Get the approx amount of rewards available for this claim interval
    * @return uint256 Rewards amount for current claim interval
    */
    function getClaimIntervalRewardsTotal() override public view returns(uint256) {
        // Get the RPL contract instance
        RocketTokenRPLInterface rplContract = RocketTokenRPLInterface(getContractAddress('rocketTokenRPL'));
        // Get the vault contract instance
        RocketVaultInterface rocketVault = RocketVaultInterface(getContractAddress('rocketVault'));
        // Rewards amount
        uint256 rewardsTotal = 0;
        // Is this the first claim of this interval? If so, calculate expected inflation RPL + any RPL already in the pool
        if(getClaimIntervalsPassed() > 0) {
            // Get the balance of tokens that will be transferred to the vault for this contract when the first claim is made
            // Also account for any RPL tokens already in the vault for the rewards pool
            rewardsTotal = rplContract.inflationCalculate().add(rocketVault.balanceOfToken('rocketRewardsPool', getContractAddress('rocketTokenRPL')));
        }else{
            // Claims have already been made, lets retrieve rewards total stored on first claim of this interval
            rewardsTotal = getUintS("rewards.pool.claim.interval.total");
        }
        // Done
        return rewardsTotal;
    }


    /**
    * Get the percentage this contract can claim in this interval
    * @return uint256 Rewards percentage this contract can claim in this interval
    */
    function getClaimingContractPerc(string memory _claimingContract) override public view returns(uint256) {
        // Load contract
        RocketDAOProtocolSettingsRewardsInterface daoSettingsRewards = RocketDAOProtocolSettingsRewardsInterface(getContractAddress('rocketDAOProtocolSettingsRewards'));
        // Get the % amount allocated to this claim contract
        uint256 claimContractPerc = daoSettingsRewards.getRewardsClaimerPerc(_claimingContract);
        // Get the block the % was changed at, it will only use this % on the next interval
        if(daoSettingsRewards.getRewardsClaimerPercBlockUpdated(_claimingContract) > getClaimIntervalBlockStartComputed()) {
            // Ok so this percentage was set during this interval, we must use the current % assigned to the last claim and the new one will kick in the next interval
            // If this is 0, the contract hasn't made a claim yet and can only do so on the next interval
            claimContractPerc = getClaimingContractPercLast(_claimingContract);
        }
        // Done
        return claimContractPerc;
    }


    /**
    * Get the approx amount of rewards available for this claim interval per claiming contract
    * @return uint256 Rewards amount for current claim interval per claiming contract
    */
    function getClaimingContractAllowance(string memory _claimingContract) override public view returns(uint256) {
        // Get the % amount this claim contract will get
        uint256 claimContractPerc = getClaimingContractPerc(_claimingContract);
        // How much rewards are available for this claim interval?
        uint256 claimIntervalRewardsTotal = getClaimIntervalRewardsTotal();
        // How much this claiming contract is entitled to in perc
        uint256 contractClaimTotal = 0;
        // Check now
        if(claimContractPerc > 0 && claimIntervalRewardsTotal > 0)  {
            // Calculate how much rewards this claimer will receive based on their claiming perc
            contractClaimTotal = claimContractPerc.mul(claimIntervalRewardsTotal).div(calcBase);
        }
        // Done
        return contractClaimTotal;
    }

    
    // How much this claimer is entitled to claim, checks parameters that claim() will check
    function getClaimAmount(string memory _claimingContract, address _claimerAddress, uint256 _claimerAmountPerc) override public view returns (uint256) { 
        // The name of the claiming contract
        string memory contractName = getContractName(msg.sender);
        // Get the total rewards available for this claiming contract
        uint256 contractClaimTotal = getClaimingContractAllowance(_claimingContract);
        // How much of the above that this claimer will receive
        uint256 claimerTotal = 0;
        // Are we good to proceed?
        if(contractClaimTotal > 0 && 
               _claimerAmountPerc > 0 && 
               _claimerAmountPerc <= 1 ether &&
               _claimerAddress != address(0x0) && 
               getClaimingContractEnabled(_claimingContract) &&
               getClaimingContractUserCanClaim(_claimingContract, _claimerAddress) && 
               !getClaimingContractUserHasClaimed(getClaimIntervalBlockStartComputed(), _claimingContract, _claimerAddress)) {

             // Now calculate how much this claimer would receive 
            claimerTotal = _claimerAmountPerc.mul(contractClaimTotal).div(calcBase);
            // Is it more than currently available + the amount claimed already for this claim interval?
            claimerTotal = claimerTotal.add(getClaimingContractTotalClaimed(contractName)) <= getClaimingContractAllowance(contractName) ? claimerTotal : 0;
        }
        // Done
        return claimerTotal;
    }

   
    // An account must be registered to claim from the rewards pool. They must wait one claim interval before they can collect.
    // Also keeps track of total 
    function registerClaimer(address _claimerAddress, bool _enabled) override external onlyClaimContract { 
        // The name of the claiming contract
        string memory contractName = getContractName(msg.sender);
        // Record the block they are registering at
        uint256 registeredBlock = 0;
        // How many users are to be included in next interval
        uint256 claimersIntervalTotalUpdate = getClaimingContractUserTotalNext(contractName);
        // Ok register
        if(_enabled) { 
            // Make sure they are not already registered
            require(getClaimingContractUserRegisteredBlock(contractName, _claimerAddress) == 0, "Claimer is already registered");
            // Update block number
            registeredBlock = block.number;
            // Update the total registered claimers for next interval
            setUint(keccak256(abi.encodePacked("rewards.pool.claim.interval.claimers.total.next", contractName)), claimersIntervalTotalUpdate.add(1));
        }else{
            setUint(keccak256(abi.encodePacked("rewards.pool.claim.interval.claimers.total.next", contractName)), claimersIntervalTotalUpdate.sub(1));
        }
        // Save the registered block
        setUint(keccak256(abi.encodePacked("rewards.pool.claim.contract.registered.block", contractName, _claimerAddress)), registeredBlock);
    }


    // A claiming contract claiming for a user and the percentage of the rewards they are allowed to receive
    function claim(address _claimerAddress, address _toAddress, uint256 _claimerAmountPerc) override external onlyEnabledClaimContract {
        // The name of the claiming contract
        string memory contractName = getContractName(msg.sender);
        // Check to see if this registered claimer has waited one interval before collecting
        require(getClaimingContractUserCanClaim(contractName, _claimerAddress), "Registered claimer is not registered to claim or has not waited one claim interval");
        // RPL contract address
        address rplContractAddress = getContractAddress('rocketTokenRPL');
        // RPL contract instance
        RocketTokenRPLInterface rplContract = RocketTokenRPLInterface(rplContractAddress);
        // Get the vault contract instance
        RocketVaultInterface rocketVault = RocketVaultInterface(getContractAddress('rocketVault'));
        // Get the start of the last claim interval as this may have just changed for a new interval beginning
        uint256 claimIntervalBlockStart = getClaimIntervalBlockStartComputed();
        // Is this the first claim of this interval? If so, set the rewards total for this interval
        if(getClaimIntervalsPassed() > 0) {
            // Mint any new tokens from the RPL inflation
            if(rplContract.getInlfationIntervalsPassed() > 0) rplContract.inflationMintTokens();
            // Get how many tokens are in the reward pool to be available for this claim period
            setUintS("rewards.pool.claim.interval.total", rocketVault.balanceOfToken('rocketRewardsPool', rplContractAddress));
            // Set this as the start of the new claim interval
            setUintS("rewards.pool.claim.interval.block.start", claimIntervalBlockStart);
            // Soon as we mint new tokens, send the DAO's share to it's claiming contract, then attempt to transfer them to the dao if possible
            uint256 daoClaimContractAllowance = getClaimingContractAllowance('rocketClaimDAO');
            // Are we sending any?
            if(daoClaimContractAllowance > 0) {
                // Get the DAO claim contract address
                address daoClaimContractAddress = getContractAddress('rocketClaimDAO');
                // Transfers the DAO's tokens to it's claiming contract from the rewards pool
                require(rocketVault.transferToken('rocketClaimDAO', rplContractAddress, daoClaimContractAllowance), "Could not transfer token balance from vault for DAO");
                // Set the current claim percentage this contract is entitled to for this interval
                setUint(keccak256(abi.encodePacked("rewards.pool.claim.interval.contract.perc.current", 'rocketClaimDAO')), getClaimingContractPerc('rocketClaimDAO'));
                // Store the total RPL rewards claim for this claiming contract in this interval
                setUint(keccak256(abi.encodePacked("rewards.pool.claim.interval.contract.total", claimIntervalBlockStart, 'rocketClaimDAO')), getClaimingContractTotalClaimed('rocketClaimDAO').add(daoClaimContractAllowance));
                // Log it
                emit RPLTokensClaimed(daoClaimContractAddress, daoClaimContractAddress, daoClaimContractAllowance, block.timestamp);
            }
        }
        // Has anyone claimed from this contract so far in this interval? If not then set the interval settings for the contract
        if(getClaimingContractTotalClaimed(contractName) == 0) {
            // Get the amount allocated to this claim contract
            uint256 claimContractAllowance = getClaimingContractAllowance(contractName);
            // Make sure this is ok
            require(claimContractAllowance > 0, "Claiming contract must have an allowance of more than 0");
            // Set the current claim percentage this contract is entitled too for this interval
            setUint(keccak256(abi.encodePacked("rewards.pool.claim.interval.contract.perc.current", contractName)), getClaimingContractPerc(contractName));
            // Set the current claim allowance amount for this contract for this claim interval (if the claim amount is changed, it will kick in on the next interval)
            setUint(keccak256(abi.encodePacked("rewards.pool.claim.interval.contract.allowance", contractName)), claimContractAllowance);
            // Set the current amount of claimers for this interval
            setUint(keccak256(abi.encodePacked("rewards.pool.claim.interval.claimers.total.current", contractName)), getClaimingContractUserTotalNext(contractName));
            
        }
        // Check if they have a valid claim amount
        uint256 claimAmount = getClaimAmount(contractName, _claimerAddress, _claimerAmountPerc);
        // First initial checks
        require(claimAmount > 0, "Claimer is not entitled to tokens, they have already claimed in this interval or they are claiming more rewards than available to this claiming contract.");
        // Send tokens now
        require(rocketVault.withdrawToken(_toAddress, rplContractAddress, claimAmount), "Could not send token balance from vault for claim");
        // Store the claiming record for this interval and claiming contract
        setBool(keccak256(abi.encodePacked("rewards.pool.claim.interval.claimer.address", claimIntervalBlockStart, contractName, _claimerAddress)), true);
        // Store the total RPL rewards claim for this claiming contract in this interval
        setUint(keccak256(abi.encodePacked("rewards.pool.claim.interval.contract.total", claimIntervalBlockStart, contractName)), getClaimingContractTotalClaimed(contractName).add(claimAmount));
        // Store the last block a claim was made
        setUintS("rewards.pool.claim.interval.block.last", block.number);
        // Log it
        emit RPLTokensClaimed(getContractAddress(contractName), _claimerAddress, claimAmount, block.timestamp);
    }

}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.18;

import "./RocketDAOProtocolSettings.sol";
import "../../../../interface/dao/protocol/settings/RocketDAOProtocolSettingsSecurityInterface.sol";

/// @notice Protocol parameters relating to the security council
contract RocketDAOProtocolSettingsSecurity is RocketDAOProtocolSettings, RocketDAOProtocolSettingsSecurityInterface {

    constructor(RocketStorageInterface _rocketStorageAddress) RocketDAOProtocolSettings(_rocketStorageAddress, "security") {
        version = 1;
        // Initialise settings on deployment
        if(!getBool(keccak256(abi.encodePacked(settingNameSpace, "deployed")))) {
            // Init settings
            setSettingUint("members.quorum", 0.51 ether);      // Member quorum threshold that must be met for proposals to pass (51%)
            setSettingUint("members.leave.time", 4 weeks);    // How long a member must give notice for before manually leaving the security council
            setSettingUint("proposal.vote.time", 2 weeks);     // How long a proposal can be voted on
            setSettingUint("proposal.execute.time", 4 weeks);  // How long a proposal can be executed after its voting period is finished
            setSettingUint("proposal.action.time", 4 weeks);   // Certain proposals require a secondary action to be run after the proposal is successful (joining, leaving etc). This is how long until that action expires
            // Settings initialised
            setBool(keccak256(abi.encodePacked(settingNameSpace, "deployed")), true);
        }
    }

    /// @dev Overrides inherited setting method with extra sanity checks for this contract
    function setSettingUint(string memory _settingPath, uint256 _value) override public onlyDAOProtocolProposal {
        // Some safety guards for certain settings
        if(keccak256(abi.encodePacked(_settingPath)) == keccak256(abi.encodePacked("members.quorum"))) require(_value > 0 ether && _value <= 1 ether, "Quorum setting must be > 0 & <= 100%");
        // Update setting now
        setUint(keccak256(abi.encodePacked(settingNameSpace, _settingPath)), _value);
    }

    /// @notice The member proposal quorum threshold for this DAO
    function getQuorum() override external view returns (uint256) {
        return getSettingUint("members.quorum");
    }

    /// @notice How long a member must give notice before leaving
    function getLeaveTime() override external view returns (uint256) {
        return getSettingUint("members.leave.time");
    }

    /// @notice How long a proposal can be voted on
    function getVoteTime() override external view returns (uint256) {
        return getSettingUint("proposal.vote.time");
    }

    /// @notice How long a proposal can be executed after its voting period is finished
    function getExecuteTime() override external view returns (uint256) {
        return getSettingUint("proposal.execute.time");
    }

    /// @notice Certain proposals require a secondary action to be run after the proposal is successful (joining, leaving etc). This is how long until that action expires
    function getActionTime() override external view returns (uint256) {
        return getSettingUint("proposal.action.time");
    }
}
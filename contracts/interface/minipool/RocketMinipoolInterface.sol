pragma solidity 0.7.6;

// SPDX-License-Identifier: GPL-3.0-only

import "../../types/MinipoolDeposit.sol";
import "../../types/MinipoolStatus.sol";
import "../RocketStorageInterface.sol";

interface RocketMinipoolInterface {
    function initialise(address _nodeAddress, MinipoolDeposit _depositType) external;
    function getStatus() external view returns (MinipoolStatus);
    function getStatusBlock() external view returns (uint256);
    function getDepositType() external view returns (MinipoolDeposit);
    function getNodeAddress() external view returns (address);
    function getNodeFee() external view returns (uint256);
    function getNodeDepositBalance() external view returns (uint256);
    function getNodeRefundBalance() external view returns (uint256);
    function getNodeDepositAssigned() external view returns (bool);
    function getUserDepositBalance() external view returns (uint256);
    function getUserDepositAssigned() external view returns (bool);
    function getUserDepositAssignedTime() external view returns (uint256);
    function getWithdrawalCredentials() external view returns (bytes memory);
    function nodeDeposit() external payable;
    function userDeposit() external payable;
    function processWithdrawal() external;
    function processWithdrawalAndDestroy() external;
    function refund() external;
    function slash() external;
    function destroy() external;
    function stake(bytes calldata _validatorPubkey, bytes calldata _validatorSignature, bytes32 _depositDataRoot) external;
    function setWithdrawable() external;
    function dissolve() external;
    function close() external;
}

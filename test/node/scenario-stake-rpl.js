import { RocketMinipoolManager, RocketDAOProtocolSettingsMinipool, RocketNetworkPrices, RocketDAOProtocolSettingsNode, RocketNodeStaking, RocketTokenRPL, RocketVault } from '../_utils/artifacts';


// Stake RPL against the node
export async function stakeRpl(amount, txOptions) {

    // Load contracts
    const [
        rocketMinipoolManager,
        rocketDAOProtocolSettingsMinipool,
        rocketNetworkPrices,
        rocketDAOProtocolSettingsNode,
        rocketNodeStaking,
        rocketTokenRPL,
        rocketVault,
    ] = await Promise.all([
        RocketMinipoolManager.deployed(),
        RocketDAOProtocolSettingsMinipool.deployed(),
        RocketNetworkPrices.deployed(),
        RocketDAOProtocolSettingsNode.deployed(),
        RocketNodeStaking.deployed(),
        RocketTokenRPL.deployed(),
        RocketVault.deployed(),
    ]);

    // Get parameters
    const [
        depositUserAmount,
        minPerMinipoolStake,
        maxPerMinipoolStake,
        rplPrice,
    ] = await Promise.all([
        rocketDAOProtocolSettingsMinipool.getHalfDepositUserAmount.call(),
        rocketDAOProtocolSettingsNode.getMinimumPerMinipoolStake.call(),
        rocketDAOProtocolSettingsNode.getMaximumPerMinipoolStake.call(),
        rocketNetworkPrices.getRPLPrice.call(),
    ]);

    // Get token balances
    function getTokenBalances(nodeAddress) {
        return Promise.all([
            rocketTokenRPL.balanceOf.call(nodeAddress),
            rocketTokenRPL.balanceOf.call(rocketVault.address),
            rocketVault.balanceOfToken.call('rocketNodeStaking', rocketTokenRPL.address),
        ]).then(
            ([nodeRpl, vaultRpl, stakingRpl]) =>
            ({nodeRpl, vaultRpl, stakingRpl})
        );
    }

    // Get staking details
    function getStakingDetails(nodeAddress) {
        return Promise.all([
            rocketNodeStaking.getTotalRPLStake.call(),
            rocketNodeStaking.getNodeRPLStake.call(nodeAddress),
            rocketNodeStaking.getNodeEffectiveRPLStake.call(nodeAddress),
            rocketNodeStaking.getNodeETHMatched.call(nodeAddress),
            rocketNodeStaking.getNodeETHMatchedLimit.call(nodeAddress),
        ]).then(
            ([totalStake, nodeStake, nodeEffectiveStake, nodeEthMatched, nodeEthMatchedLimit]) =>
            ({totalStake, nodeStake, nodeEffectiveStake, nodeEthMatched, nodeEthMatchedLimit})
        );
    }

    // Get minipool counts
    function getMinipoolCounts(nodeAddress) {
        return Promise.all([
            rocketMinipoolManager.getMinipoolCount.call(),
            rocketMinipoolManager.getNodeMinipoolCount.call(nodeAddress),
            rocketMinipoolManager.getStakingMinipoolCount.call(),
            rocketMinipoolManager.getNodeStakingMinipoolCount.call(nodeAddress),
        ]).then(
            ([total, node, totalStaking, nodeEthMatched, nodeStaking]) =>
            ({total, node, totalStaking, nodeEthMatched, nodeStaking})
        );
    }

    // Get initial token balances & staking details
    let [balances1, details1] = await Promise.all([
        getTokenBalances(txOptions.from),
        getStakingDetails(txOptions.from),
    ]);

    // Stake RPL
    await rocketNodeStaking.stakeRPL(amount, txOptions);

    // Get updated token balances, staking details & minipool counts
    let [balances2, details2, minipoolCounts] = await Promise.all([
        getTokenBalances(txOptions.from),
        getStakingDetails(txOptions.from),
        getMinipoolCounts(txOptions.from),
    ]);

    // Calculate expected effective stakes & node minipool limit
    const maxNodeEffectiveStake = details2.nodeEthMatched.mul(maxPerMinipoolStake).div(rplPrice);
    const expectedNodeEffectiveStake = (details2.nodeStake.lt(maxNodeEffectiveStake) ? details2.nodeStake : maxNodeEffectiveStake);
    const expectedNodeEthMatchedLimit = details2.nodeStake.mul(rplPrice).div(minPerMinipoolStake);

    // Check token balances
    assert(balances2.nodeRpl.eq(balances1.nodeRpl.sub(web3.utils.toBN(amount))), 'Incorrect updated node RPL balance');
    assert(balances2.vaultRpl.eq(balances1.vaultRpl.add(web3.utils.toBN(amount))), 'Incorrect updated vault RPL balance');
    assert(balances2.stakingRpl.eq(balances1.stakingRpl.add(web3.utils.toBN(amount))), 'Incorrect updated RocketNodeStaking contract RPL vault balance');

    // Check staking details
    assert(details2.totalStake.eq(details1.totalStake.add(web3.utils.toBN(amount))), 'Incorrect updated total RPL stake');
    assert(details2.nodeStake.eq(details1.nodeStake.add(web3.utils.toBN(amount))), 'Incorrect updated node RPL stake');
    assert(details2.nodeEffectiveStake.eq(expectedNodeEffectiveStake), 'Incorrect updated effective node RPL stake');
    assert(details2.nodeEthMatchedLimit.eq(expectedNodeEthMatchedLimit), 'Incorrect updated node minipool limit');

}


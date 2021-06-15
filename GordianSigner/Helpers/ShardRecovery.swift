//
//  ShardRecovery.swift
//  GordianSigner
//
//  Created by Peter Denton on 3/19/21.
//  Copyright © 2021 Blockchain Commons. All rights reserved.
//

import Foundation
import SSKR
import URKit

class ShardRecovery {
    
    static let shared = ShardRecovery()
    
    private var rawShards = [String]()
    private var shares = [SSKRShare]()
    public var shards = [Shard]()
    private var groups = [Int]()
    
    func reset() {
        rawShards.removeAll()
        shares.removeAll()
        shards.removeAll()
        groups.removeAll()
    }
    
    func parseUr(_ ur: String) -> (valid: Bool, alreadyAdded: Bool, shard: String) {
        let shard = URHelper.urToShard(sskrUr: ur) ?? ""
        guard shard != "" else { return (false, false, shard) }
        guard shardAlreadyAdded(shard) == false else { return (true, true, shard) }
        rawShards.append(shard)
        
        guard let data = URHelper.urShardToShardData(sskrUr: ur) else { return (false, false, shard) }
        let share = SSKRShare(data: data.bytes)
        shares.append(share)
        return (true, false, shard)
    }
    
    func shardAlreadyAdded(_ shard: String) -> Bool {
        guard rawShards.count > 0 else { return false }
        var shardAlreadyExists = false
        for s in rawShards {
            if shard == s {
                shardAlreadyExists = true
            }
        }
        return shardAlreadyExists
    }
    
    func processShard(_ shard: Shard) -> (complete: Bool, entropy: Data?, totalSharesRemainingInGroup: Int) {
        let totalGroupsRequired = shard.groupThreshold
        let totalMembersRequired = shard.memberThreshold
        let group = shard.groupIndex
        var existingShardsInGroup = 0
        
        for s in shards {
            if s.groupIndex == group {
                existingShardsInGroup += 1
            }
        }
        
        let totalSharesRemainingInGroup = totalMembersRequired - existingShardsInGroup
        
        if existingShardsInGroup == totalMembersRequired {
            for s in shards {
                groups.append(s.groupIndex)
            }
        } else {
            return (false, nil, totalSharesRemainingInGroup)
        }
        
        let uniqueGroups = Array(Set(groups))
        
        if uniqueGroups.count == totalGroupsRequired {
            // DING DING DING DING DING DING DING DING DING DING
            guard let recoveredEntropy = try? SSKRCombine(shares: shares) else {
                return (false, nil, totalSharesRemainingInGroup)
            }
            
            return (true, recoveredEntropy, totalSharesRemainingInGroup)
        } else {
            
            return (false, nil, totalSharesRemainingInGroup)
        }
    }
    
    func parseShard(_ shard: String) -> Shard? {
        let id = shard.prefix(4)
        let shareValue = shard.replacingOccurrences(of: shard.prefix(10), with: "") /// the length of this value should equal the length of the master seed
        let array = Array(shard)
        
        guard let groupThresholdIndex = Int("\(array[4])"),                         /// required # of groups
            let groupCountIndex = Int("\(array[5])"),                               /// total # of possible groups
            let groupIndex = Int("\(array[6])"),                                    /// # the group this share belongs to
            let memberThresholdIndex = Int("\(array[7])"),                          /// # of shares required from this group
            let reserved = Int("\(array[8])"),                                      /// MUST be 0
            let memberIndex = Int("\(array[9])") else { return nil }                ///  the shares member # within its group
        
        let dict = [
            
            "id": id,
            "shareValue": shareValue,                                               /// the length of this value should equal the length of the master seed
            "groupThreshold": groupThresholdIndex + 1,                              /// required # of groups
            "groupCount": groupCountIndex + 1,                                      /// total # of possible groups
            "groupIndex": groupIndex + 1,                                           /// the group this share belongs to
            "memberThreshold": memberThresholdIndex + 1,                            /// # of shares required from this group
            "reserved": reserved,                                                   /// MUST be 0
            "memberIndex": memberIndex + 1,                                         /// the shares member # within its group
            "raw": shard
            
        ] as [String:Any]
        
        return Shard(dictionary: dict)
    }
    
}

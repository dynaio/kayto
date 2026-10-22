package com.kayto.kayto.model

data class SimInfo(
    val slotIndex: Int,          // 0 for SIM 1, 1 for SIM 2
    val subscriptionId: Int,
    val displayName: String,
    val carrierName: String,
    val isDefaultData: Boolean,
    val subscriberId: String? = null
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "slotIndex" to slotIndex,
        "subscriptionId" to subscriptionId,
        "displayName" to displayName,
        "carrierName" to carrierName,
        "isDefaultData" to isDefaultData
    )
}

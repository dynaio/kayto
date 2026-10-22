package com.kayto.kayto.model

enum class NetworkSource {
    WIFI,
    SIM_1,
    SIM_2;

    companion object {
        fun fromString(value: String): NetworkSource {
            return when (value.uppercase()) {
                "WIFI" -> WIFI
                "SIM_1", "SIM1" -> SIM_1
                "SIM_2", "SIM2" -> SIM_2
                else -> WIFI
            }
        }
    }
}
